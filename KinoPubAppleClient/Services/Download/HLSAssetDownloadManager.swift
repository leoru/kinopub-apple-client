//
//  HLSAssetDownloadManager.swift
//  KinoPubAppleClient
//
//  Downloads HLS streams (master .m3u8) for offline playback using
//  AVAssetDownloadURLSession + AVAggregateAssetDownloadTask so that ALL audio
//  tracks (озвучки) and subtitles are downloaded alongside the video and remain
//  switchable during offline playback.
//
//  IMPORTANT: AVAssetDownloadURLSession / AVAggregateAssetDownloadTask are
//  iOS/tvOS only — NOT available on macOS. All AVAssetDownload* usage is gated
//  behind `#if os(iOS)`. On macOS this type exists as a no-op so shared code
//  (AppContext, DownloadsCatalog, MediaItemModel) compiles unchanged; the macOS
//  download path continues to use the mp4 `DownloadManager`.
//

import Foundation
import Combine
import KinoPubBackend
import KinoPubLogging
import OSLog
import AVFoundation

/// Lightweight, UI-facing description of an in-flight HLS download.
public struct HLSActiveDownload: Identifiable, Equatable {
  public let id: String        // taskDescription key (meta id + video + season)
  public let meta: DownloadMeta
  public var progress: Float
  /// Current transfer rate in bytes/sec (from the .movpkg growing on disk).
  public var speed: Double
  /// Estimated time remaining, derived from the progress rate.
  public var remaining: TimeInterval?

  public init(id: String, meta: DownloadMeta, progress: Float, speed: Double = 0, remaining: TimeInterval? = nil) {
    self.id = id
    self.meta = meta
    self.progress = progress
    self.speed = speed
    self.remaining = remaining
  }
}

/// A download that was interrupted by the app being force-quit (its background task didn't survive),
/// so it can't be resumed — surfaced in the UI so the user can re-download it.
public struct HLSInterruptedDownload: Identifiable, Equatable {
  public let id: String   // HLSDownloadKey
  public let meta: DownloadMeta

  public init(id: String, meta: DownloadMeta) {
    self.id = id
    self.meta = meta
  }
}

/// Outcome of trying to start an HLS download, so the UI can tell the user exactly what happened.
public enum HLSDownloadStartResult: Equatable {
  case started
  case alreadyDownloading
  case alreadyDownloaded
  case failed(String)
}

/// Stable key used as the task description so we can re-associate background
/// tasks with their metadata after an app relaunch.
enum HLSDownloadKey {
  static func make(for meta: DownloadMeta) -> String {
    "\(meta.id)|\(meta.metadata.video.map(String.init) ?? "-")|\(meta.metadata.season.map(String.init) ?? "-")"
  }
}

#if os(iOS)

public final class HLSAssetDownloadManager: NSObject, ObservableObject, AVAssetDownloadDelegate {

  /// In-flight downloads keyed by `HLSDownloadKey`.
  @Published public private(set) var activeDownloads: [HLSActiveDownload] = []
  /// Downloads whose background task didn't survive a force-quit — shown so the user can re-download.
  @Published public private(set) var interrupted: [HLSInterruptedDownload] = []
  /// Last download failure reason, surfaced to the user so a failed download isn't silent.
  @Published public var lastError: String?

  private let store: HLSDownloadsStore
  /// Maximum desired resolution height (px) used to derive a bitrate cap, or nil
  /// for "best available" (adaptive). Injected from the app's StreamQuality
  /// setting where one exists.
  private let maxResolutionProvider: () -> Int?

  /// Notification hooks (mirrors the mp4 path). Optional so macOS / tests can omit.
  public var onDownloadFinished: ((DownloadMeta) -> Void)?
  public var onDownloadFailed: ((DownloadMeta) -> Void)?

  // Per-running-task state.
  private struct TaskContext {
    let meta: DownloadMeta
    let hlsURL: URL
    let retryCount: Int
    var downloadURL: URL?      // the .movpkg location handed to us by the delegate
    // Aggregate progress across every media selection (video + each audio track + subtitles): the
    // delegate reports progress PER selection (each restarts from 0), so we keep the latest fraction
    // of each and average over the total, instead of showing one selection's progress and resetting.
    var totalSelections: Int = 1
    var selectionFractions: [String: Double] = [:]
    // Speed (from the .movpkg growing on disk) + ETA (from the progress rate).
    var lastBytes: Int64 = 0
    var lastBytesTime: Date?
    var speed: Double = 0
    var lastProgress: Float = 0
    var lastProgressTime: Date?
    var remaining: TimeInterval?
  }
  private var contexts: [Int: TaskContext] = [:]   // keyed by task.taskIdentifier
  /// kino.pub rate-limits (HTTP 429) aggressive HLS downloads; we retry with backoff this many times.
  private let maxRetries = 5

  /// Persisted record of an in-flight download so it can be resumed (background task survived) or
  /// re-offered (force-quit) after a relaunch — the system keeps the task, but the meta lives only in
  /// memory, so without this the delegate can't recover it.
  private struct PendingHLSDownload: Codable, Equatable {
    let key: String
    let meta: DownloadMeta
    let hlsURLString: String
    var retryCount: Int
    /// Relative path of the partial `.movpkg` (once the system hands us a location) so we can delete
    /// it on cleanup.
    var partialRelativePath: String?
  }

  private let pendingFileURL: URL = {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return documents.appendingPathComponent("hlsPendingDownloads.plist")
  }()

  private func readPending() -> [PendingHLSDownload] {
    guard let data = try? Data(contentsOf: pendingFileURL),
          let decoded = try? PropertyListDecoder().decode([PendingHLSDownload].self, from: data) else { return [] }
    return decoded
  }

  private func writePending(_ items: [PendingHLSDownload]) {
    if let data = try? PropertyListEncoder().encode(items) { try? data.write(to: pendingFileURL) }
  }

  private func savePending(_ entry: PendingHLSDownload) {
    var items = readPending()
    items.removeAll { $0.key == entry.key }
    items.append(entry)
    writePending(items)
  }

  private func removePending(key: String) {
    var items = readPending()
    let before = items.count
    items.removeAll { $0.key == key }
    if items.count != before { writePending(items) }
  }

  private func updatePendingPartial(key: String, relativePath: String) {
    var items = readPending()
    guard let idx = items.firstIndex(where: { $0.key == key }) else { return }
    items[idx].partialRelativePath = relativePath
    writePending(items)
  }

  /// Deletes the partial `.movpkg` left behind by an interrupted download, if its location was recorded.
  private func deletePartial(_ entry: PendingHLSDownload) {
    guard let relativePath = entry.partialRelativePath else { return }
    let url = URL(fileURLWithPath: NSHomeDirectory() + "/" + relativePath)
    try? FileManager.default.removeItem(at: url)
  }

  public init(store: HLSDownloadsStore,
              maxResolutionProvider: @escaping () -> Int? = { nil }) {
    self.store = store
    self.maxResolutionProvider = maxResolutionProvider
    super.init()
    _ = session // force lazy creation so background tasks are reattached
  }

  private lazy var session: AVAssetDownloadURLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: "com.kinopub.hlsDownloadSession")
    return AVAssetDownloadURLSession(configuration: config,
                                     assetDownloadDelegate: self,
                                     delegateQueue: .main)
  }()

  // MARK: - Public API

  /// Starts (or no-ops if already running) an HLS download of `hlsURL` for `meta`, returning what
  /// happened so the caller can tell the user (including *why* it didn't start).
  @discardableResult
  public func startDownload(meta: DownloadMeta, hlsURL: URL) -> HLSDownloadStartResult {
    let key = HLSDownloadKey.make(for: meta)

    // Already downloading?
    if activeDownloads.contains(where: { $0.id == key }) {
      Logger.kit.debug("[HLS] download already active for key \(key)")
      return .alreadyDownloading
    }
    // Already downloaded?
    if store.asset(forId: meta.id, video: meta.metadata.video, season: meta.metadata.season) != nil {
      Logger.kit.debug("[HLS] asset already downloaded for key \(key)")
      return .alreadyDownloaded
    }
    return launch(meta: meta, hlsURL: hlsURL, retryCount: 0)
      ? .started
      : .failed(lastError ?? "Couldn't start download".localized)
  }

  /// Builds and resumes an aggregate download. Attempts 0…maxRetries-2 grab every audio (озвучка) +
  /// subtitle track; the final attempt narrows to the preferred selection (video + default audio) so
  /// a heavily rate-limited title can still complete rather than failing outright.
  @discardableResult
  private func launch(meta: DownloadMeta, hlsURL: URL, retryCount: Int) -> Bool {
    let key = HLSDownloadKey.make(for: meta)
    let asset = AVURLAsset(url: hlsURL)
    let narrow = retryCount >= maxRetries - 1

    var mediaSelections: [AVMediaSelection] = []
    if !narrow, let baseSelection = asset.preferredMediaSelection.mutableCopy() as? AVMutableMediaSelection {
      for characteristic in [AVMediaCharacteristic.audible, .legible] {
        guard let group = asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) else { continue }
        for option in group.options {
          guard let selection = baseSelection.mutableCopy() as? AVMutableMediaSelection else { continue }
          selection.select(option, in: group)
          mediaSelections.append(selection)
        }
      }
    }
    // Always include the preferred selection (video + default tracks).
    mediaSelections.append(asset.preferredMediaSelection)

    var options: [String: Any] = [:]
    if let maxResolution = maxResolutionProvider() {
      let bitrate = max(800_000, (maxResolution / 360) * 2_000_000)
      options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = bitrate
    }

    guard let task = session.aggregateAssetDownloadTask(with: asset,
                                                        mediaSelections: mediaSelections,
                                                        assetTitle: meta.localizedTitle,
                                                        assetArtworkData: nil,
                                                        options: options.isEmpty ? nil : options) else {
      Logger.kit.error("[HLS] failed to create aggregate download task for key \(key)")
      activeDownloads.removeAll(where: { $0.id == key })
      lastError = String(format: "Couldn't start downloading “%@” (the server didn't return a valid HLS stream).".localized,
                         meta.notificationTitle)
      onDownloadFailed?(meta)
      return false
    }

    task.taskDescription = key
    contexts[task.taskIdentifier] = TaskContext(meta: meta, hlsURL: hlsURL, retryCount: retryCount)
    contexts[task.taskIdentifier]?.totalSelections = max(1, mediaSelections.count)
    // Persist so a relaunch can resume (task survived) or re-offer (force-quit) this download.
    savePending(PendingHLSDownload(key: key, meta: meta, hlsURLString: hlsURL.absoluteString,
                                   retryCount: retryCount, partialRelativePath: nil))
    interrupted.removeAll { $0.id == key }
    if let idx = activeDownloads.firstIndex(where: { $0.id == key }) {
      activeDownloads[idx].progress = 0   // keep the row visible across retries
    } else {
      activeDownloads.append(HLSActiveDownload(id: key, meta: meta, progress: 0))
    }
    task.resume()
    lastError = nil
    Logger.kit.debug("[HLS] started download for key \(key) (attempt \(retryCount + 1), narrow: \(narrow))")
    return true
  }

  /// Cancels an in-flight download for the given key.
  public func cancelDownload(key: String) {
    session.getAllTasks { [weak self] tasks in
      for task in tasks where task.taskDescription == key {
        task.cancel()
      }
      DispatchQueue.main.async {
        self?.activeDownloads.removeAll(where: { $0.id == key })
      }
    }
  }

  /// After a relaunch: reattach any background task that survived (resume — rebuild its context so the
  /// delegate keeps reporting progress and persists on completion), and surface any whose task didn't
  /// survive a force-quit as `interrupted` so the user can re-download. Metadata comes from the
  /// persisted pending store (the system only gives us back the `taskDescription` key).
  public func restorePendingDownloads() {
    let pending = readPending()
    // Reclaim orphaned .movpkg bundles left by failed/cancelled/retried downloads — keeping anything
    // still tracked (saved downloads + in-flight/interrupted partials).
    let keepPartials = Set(pending.compactMap { $0.partialRelativePath })
    DispatchQueue.global(qos: .utility).async { [store] in
      store.sweepOrphans(keepRelativePaths: keepPartials)
    }
    guard !pending.isEmpty else { return }

    session.getAllTasks { [weak self] tasks in
      guard let self else { return }
      var liveTasksByKey: [String: AVAggregateAssetDownloadTask] = [:]
      for task in tasks {
        if let aggregate = task as? AVAggregateAssetDownloadTask, let key = aggregate.taskDescription {
          liveTasksByKey[key] = aggregate
        }
      }

      DispatchQueue.main.async {
        var interruptedNow: [HLSInterruptedDownload] = []
        for entry in pending {
          // Completed in the background while we were away → already in the store; drop the pending row.
          if self.store.asset(forId: entry.meta.id,
                              video: entry.meta.metadata.video,
                              season: entry.meta.metadata.season) != nil {
            self.removePending(key: entry.key)
            continue
          }
          if let task = liveTasksByKey[entry.key], let url = URL(string: entry.hlsURLString) {
            // Background task survived → rebuild context so progress + completion resume.
            self.contexts[task.taskIdentifier] = TaskContext(meta: entry.meta, hlsURL: url,
                                                             retryCount: entry.retryCount)
            if !self.activeDownloads.contains(where: { $0.id == entry.key }) {
              self.activeDownloads.append(HLSActiveDownload(id: entry.key, meta: entry.meta, progress: 0))
            }
          } else {
            // No live task (force-quit) → can't resume; offer a re-download.
            interruptedNow.append(HLSInterruptedDownload(id: entry.key, meta: entry.meta))
          }
        }
        self.interrupted = interruptedNow
      }
    }
  }

  /// A stable identifier for a media selection (its chosen audio + subtitle options), so progress
  /// callbacks for the same selection update one bucket instead of creating a new one each time.
  private static func selectionKey(for selection: AVMediaSelection) -> String {
    guard let asset = selection.asset else { return "default" }
    var parts: [String] = []
    for characteristic in [AVMediaCharacteristic.audible, .legible] {
      if let group = asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) {
        parts.append(selection.selectedMediaOption(in: group)?.displayName ?? "-")
      } else {
        parts.append("-")
      }
    }
    return parts.joined(separator: "|")
  }

  // MARK: - AVAssetDownloadDelegate

  /// Gives us the local `.movpkg` location. Apple: persist the RELATIVE path and
  /// do not move the bundle.
  public func urlSession(_ session: URLSession,
                         aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                         willDownloadTo location: URL) {
    Logger.kit.debug("[HLS] willDownloadTo \(location.relativePath)")
    contexts[aggregateAssetDownloadTask.taskIdentifier]?.downloadURL = location
    if let key = aggregateAssetDownloadTask.taskDescription {
      updatePendingPartial(key: key, relativePath: location.relativePath)
    }
  }

  /// Progress for the currently-downloading media selection.
  public func urlSession(_ session: URLSession,
                         aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                         didLoad timeRange: CMTimeRange,
                         totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                         timeRangeExpectedToLoad: CMTimeRange,
                         for mediaSelection: AVMediaSelection) {
    let id = aggregateAssetDownloadTask.taskIdentifier
    guard var ctx = contexts[id] else { return }

    var loadedSeconds = 0.0
    for value in loadedTimeRanges {
      loadedSeconds += CMTimeGetSeconds(value.timeRangeValue.duration)
    }
    let expected = CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
    guard expected > 0 else { return }

    // Record THIS selection's fraction, then average across all selections so the bar climbs smoothly
    // 0→100 over the whole container instead of resetting each time a new track starts downloading.
    ctx.selectionFractions[Self.selectionKey(for: mediaSelection)] = min(1.0, loadedSeconds / expected)
    let denominator = Double(max(ctx.totalSelections, ctx.selectionFractions.count))
    let progress = Float(min(1.0, ctx.selectionFractions.values.reduce(0, +) / denominator))

    let now = Date()
    // ETA from the progress rate (cheap, no disk access).
    if let last = ctx.lastProgressTime {
      let dt = now.timeIntervalSince(last)
      if dt >= 1.0, progress > ctx.lastProgress {
        let rate = Double(progress - ctx.lastProgress) / dt   // fraction / sec
        if rate > 0 { ctx.remaining = Double(1 - progress) / rate }
        ctx.lastProgress = progress
        ctx.lastProgressTime = now
      }
    } else {
      ctx.lastProgress = progress
      ctx.lastProgressTime = now
    }
    // Speed from the .movpkg growing on disk, sampled every ~2s (enumerating the bundle isn't free).
    if let location = ctx.downloadURL,
       ctx.lastBytesTime == nil || now.timeIntervalSince(ctx.lastBytesTime ?? now) >= 2.0 {
      let bytes = HLSDownloadsStore.directorySize(at: location)
      if let lastTime = ctx.lastBytesTime {
        let dt = now.timeIntervalSince(lastTime)
        if dt > 0 { ctx.speed = max(0, Double(bytes - ctx.lastBytes) / dt) }
      }
      ctx.lastBytes = bytes
      ctx.lastBytesTime = now
    }
    contexts[id] = ctx

    if let key = aggregateAssetDownloadTask.taskDescription,
       let idx = activeDownloads.firstIndex(where: { $0.id == key }) {
      activeDownloads[idx].progress = progress
      activeDownloads[idx].speed = ctx.speed
      activeDownloads[idx].remaining = ctx.remaining
    }
  }

  /// Completion. On success persist a record (relative path); on failure notify.
  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    let id = task.taskIdentifier
    guard let ctx = contexts[id] else { return }
    let key = task.taskDescription ?? HLSDownloadKey.make(for: ctx.meta)
    contexts[id] = nil

    if let error = error as NSError? {
      // Cancellation isn't a "failure" worth notifying about.
      if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
        Logger.kit.debug("[HLS] download cancelled for key \(key)")
        activeDownloads.removeAll(where: { $0.id == key })
        removePending(key: key)
        return
      }
      // kino.pub rate-limits aggressive HLS downloads (HTTP 429 → CoreMedia -16845). These are
      // transient: wait with exponential backoff and resume — AVFoundation keeps the partial
      // .movpkg, and the final retry narrows to the default track so it can finish.
      let rateLimited = error.code == -16845 || error.localizedDescription.contains("429")
      if rateLimited, ctx.retryCount < maxRetries {
        let delays: [UInt64] = [5, 15, 30, 60, 120]
        let seconds = delays[min(ctx.retryCount, delays.count - 1)]
        let next = ctx.retryCount + 1
        // The failed attempt's partial .movpkg won't be reused by the fresh task — delete it so
        // retries don't pile up abandoned bundles (the main cause of runaway disk usage).
        if let partial = ctx.downloadURL {
          try? FileManager.default.removeItem(at: partial)
        }
        Logger.kit.error("[HLS] rate-limited (429) for key \(key); retry \(next + 1) in \(seconds)s")
        Task { @MainActor [weak self] in
          try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
          self?.launch(meta: ctx.meta, hlsURL: ctx.hlsURL, retryCount: next)
        }
        return  // keep the active row visible while we wait
      }
      Logger.kit.error("[HLS] download failed for key \(key): \(error)")
      activeDownloads.removeAll(where: { $0.id == key })
      removePending(key: key)
      lastError = String(format: "“%@” failed to download: %@".localized,
                         ctx.meta.notificationTitle, error.localizedDescription)
      onDownloadFailed?(ctx.meta)
      return
    }

    activeDownloads.removeAll(where: { $0.id == key })
    guard let location = ctx.downloadURL else {
      Logger.kit.error("[HLS] download finished but no location for key \(key)")
      removePending(key: key)
      lastError = String(format: "“%@” failed to download (no file was produced).".localized,
                         ctx.meta.notificationTitle)
      onDownloadFailed?(ctx.meta)
      return
    }

    let asset = HLSDownloadedAsset(meta: ctx.meta,
                                   relativePath: location.relativePath,
                                   downloadDate: Date())
    store.save(asset)
    removePending(key: key)
    Logger.kit.info("[HLS] download finished for key \(key)")
    onDownloadFinished?(ctx.meta)
  }

  // MARK: - Resume / re-download after relaunch

  /// Re-download an interrupted item from scratch (deleting any stale partial first).
  public func retryInterrupted(_ key: String) {
    guard let entry = readPending().first(where: { $0.key == key }),
          let url = URL(string: entry.hlsURLString) else {
      interrupted.removeAll { $0.id == key }
      return
    }
    deletePartial(entry)
    interrupted.removeAll { $0.id == key }
    launch(meta: entry.meta, hlsURL: url, retryCount: 0)
  }

  /// Drop an interrupted item and clean up its partial `.movpkg`.
  public func dismissInterrupted(_ key: String) {
    if let entry = readPending().first(where: { $0.key == key }) {
      deletePartial(entry)
    }
    removePending(key: key)
    interrupted.removeAll { $0.id == key }
  }
}

#else

// macOS (and any non-iOS platform): no-op shim with the same public surface so
// shared code compiles. The mp4 DownloadManager handles downloads on macOS.
public final class HLSAssetDownloadManager: ObservableObject {

  @Published public private(set) var activeDownloads: [HLSActiveDownload] = []
  @Published public private(set) var interrupted: [HLSInterruptedDownload] = []
  @Published public var lastError: String?

  public var onDownloadFinished: ((DownloadMeta) -> Void)?
  public var onDownloadFailed: ((DownloadMeta) -> Void)?

  public init(store: HLSDownloadsStore,
              maxResolutionProvider: @escaping () -> Int? = { nil }) {}

  @discardableResult
  public func startDownload(meta: DownloadMeta, hlsURL: URL) -> HLSDownloadStartResult {
    Logger.kit.debug("[HLS] HLS downloads are not supported on this platform; ignoring.")
    return .failed("HLS downloads are not supported on this platform.")
  }

  public func cancelDownload(key: String) {}

  public func restorePendingDownloads() {}

  public func retryInterrupted(_ key: String) {}

  public func dismissInterrupted(_ key: String) {}
}

#endif
