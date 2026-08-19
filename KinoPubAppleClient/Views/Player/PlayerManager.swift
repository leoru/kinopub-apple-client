//
//  PlayerManager.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 3.08.2023.
//

import Foundation
import SwiftUI
import Combine
import KinoPubBackend
import KinoPubKit
import AVFoundation
import KinoPubLogging
import OSLog
#if os(tvOS)
import AVKit
import UIKit
#endif

enum WatchMode: Equatable {
  case media
  case trailer
}

/// What the player screen shows besides video: a spinner (with a way out) while the
/// stream is prepared, nothing once it's ready, the reason when it failed. The player
/// must never sit on a silent black screen.
enum PlaybackState: Equatable {
  case preparing
  case ready
  case failed(String)
}

class PlayerManager: ObservableObject {

  @Published var isPlaying: Bool = false
  @Published var watchMark: WatchData?
  @Published var activeCue: SubtitleCue?
  @Published var activeSecondaryCue: SubtitleCue?
  @Published var lastCue: SubtitleCue?
  @Published var subtitlesEnabled: Bool = false
  @Published var currentPlaybackTime: TimeInterval = 0
  @Published private(set) var playbackState: PlaybackState = .preparing

  /// Every subtitle track this item offers, and the two that are showing.
  @Published private(set) var subtitleTracks: [SubtitleTrack] = []
  @Published private(set) var primaryTrack: SubtitleTrack?
  @Published private(set) var secondaryTrack: SubtitleTrack?

  let player = AVPlayer()
  private var playerTimeObserver: PlayerTimeObserver?
  private var cueObserverToken: Any?
  private var playItem: any PlayableItem
  private var watchMode: WatchMode
  private var downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>
  private var rateObservation: NSKeyValueObservation?
  private var actionsService: UserActionsService
  /// Only for resolving missing stream links — see `resolveStreamLinksIfNeeded`.
  private let contentService: VideoContentService
  private var cues: [SubtitleCue] = []
  private var secondaryCues: [SubtitleCue] = []
  private var cueLoadTasks: [Task<Void, Never>] = []
  private var didPreparePlayback = false
  /// Playback position of the last successful `/v1/watching/marktime` tick.
  private var lastServerMarkPosition: TimeInterval = 0
  /// Server marktime cadence — local resume stays on the observer's 10s period.
  private static let serverMarkInterval: TimeInterval = 30
  /// Held strongly: `AVAssetResourceLoader` only keeps a weak reference to its delegate.
  private var masterLoader: HLSMasterResourceLoader?
  private var statusObservation: NSKeyValueObservation?
  private var seekObservation: NSKeyValueObservation?
  private var playbackFailureObserver: NSObjectProtocol?
  private var endOfPlaybackObserver: NSObjectProtocol?
  /// Set once the resume point has been asked for, so a re-entering view cannot ask twice.
  private var didFetchWatchMark = false
  /// Resume point waiting for the item to become `readyToPlay` (fetch often races prepare).
  private var pendingResumeTime: TimeInterval?
  private static let loaderQueue = DispatchQueue(label: "com.soda.kinopub.hls-master-loader")

#if os(tvOS)
  /// The system player screen we drive on tvOS. Held weakly: AVKit owns it, we only
  /// reach in to hang metadata and the transport-bar menus off it.
  private weak var playerViewController: AVPlayerViewController?
  /// Fires once the asset has published its audio renditions, which is when a sensible
  /// default track can be chosen.
  private var audioReadyObservation: NSKeyValueObservation?
  /// The `.audible` group and its options, cached once the item is ready so the menu and
  /// the checkmarks don't have to re-read the asset on every rebuild.
  private var audibleGroup: AVMediaSelectionGroup?
  /// Set once we've auto-picked a default, so a later readiness callback can't stomp a
  /// manual choice the user made in the meantime.
  private var didChooseDefaultAudio = false
  /// The last dub name written to `AudioTrackMemory`, so the polling persist only writes
  /// on an actual change.
  private var lastPersistedAudioName: String?
#endif

  /// Optional on purpose: both of these used to force-unwrap, and `URL(string: "")`
  /// is nil — an item without a trailer link crashed the app on open.
  private var fileURL: URL? {
    switch watchMode {
    case .media:
      // DownloadMeta.id is the series/content id; Episode.id is the episode id while
      // metadata.id is the series. Match either so a downloaded item opened from detail
      // plays locally instead of streaming.
      let contentIds: Set<Int> = [playItem.id, playItem.metadata.id]
      for contentId in contentIds {
        if let hls = AppContext.shared.hlsDownloadsStore.asset(
          forId: contentId,
          video: playItem.metadata.video,
          season: playItem.metadata.season
        ) {
          return hls.localFileURL
        }
      }
      let downloadedFiles = downloadedFilesDatabase.readData() ?? []
      let sameItem = downloadedFiles.filter { contentIds.contains($0.metadata.id) }
      let playURLs = Set(playItem.files.map(\.url.http))
      let chosen = sameItem.first(where: { playURLs.contains($0.originalURL.absoluteString) })
        ?? sameItem.first
      if let chosen, FileManager.default.fileExists(atPath: chosen.localFileURL.path) {
        return chosen.localFileURL
      }
      let urlString = BestVideoQualityFinder.findBestURL(for: playItem.files)
      guard !urlString.isEmpty else { return nil }
      return URL(string: urlString)
    case .trailer:
      return playItem.trailerURL
    }
  }

  init(playItem: any PlayableItem,
       watchMode: WatchMode,
       downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>,
       actionsService: UserActionsService,
       contentService: VideoContentService = AppContext.shared.contentService) {
    self.playItem = playItem
    self.watchMode = watchMode
    self.actionsService = actionsService
    self.downloadedFilesDatabase = downloadedFilesDatabase
    self.contentService = contentService
    rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
      DispatchQueue.main.async {
        self?.isPlaying = player.rate > 0
      }
    }

    // Local resume every ~10s; server marktime every ~30s (see `saveWatchMark`).
    playerTimeObserver = PlayerTimeObserver(player: player, period: 10.0, timeUpdateHandler: { [weak self] time in
      self?.saveWatchMark(time: time)
#if os(tvOS)
      self?.persistAudioSelectionIfNeeded()
#endif
    })

    addCueTimeObserver()
    configureSubtitles()
  }

  /// Loads the playable URL into `player`. Safe to call more than once; only the first
  /// run does work. Playback starts immediately — the audio-name rewrite happens inside
  /// the resource loader while the master is being fetched, never as a step before it.
  @MainActor
  func preparePlayback() async {
    guard !didPreparePlayback else { return }
    didPreparePlayback = true

    await resolveStreamLinksIfNeeded()

    guard let source = fileURL else {
      Logger.app.error("No playable URL for item \(self.playItem.id) in \(String(describing: self.watchMode)) mode")
      playbackState = .failed("No playable link for this item".localized)
      return
    }

    // The stream we are about to open, by host and kind — a TLS / reset failure from the
    // CDN and "we picked the wrong link" look identical on screen otherwise.
    Logger.app.info(
      "play mode=\(String(describing: self.watchMode)) item=\(self.playItem.id) files=\(self.playItem.files.count) host=\(source.host ?? "local") kind=\(source.pathExtension)"
    )
    let item = AVPlayerItem(asset: playbackAsset(for: source))
    // Cap adaptive HLS to the user's chosen quality. Harmless for local/trailer playback.
    if watchMode == .media, let maxResolution = StreamQuality.current.maxResolution {
      item.preferredMaximumResolution = maxResolution
    }
    observePlaybackState(of: item)
    observeEndOfPlayback(of: item)
    player.replaceCurrentItem(with: item)
#if os(iOS) || os(tvOS)
    // AVPlayerItem.externalMetadata is absent on macOS (AVPlayerView / the window title
    // bar carry the name there instead) — see the customization-surface table in
    // player-and-media.md.
    configureExternalMetadata()
#endif
#if os(tvOS)
    audibleGroup = nil
    didChooseDefaultAudio = false
    configureDefaultAudioWhenReady()
    rebuildTransportBarMenus()
#endif
  }

  /// An episode that came from a `nolinks=1` details call has no files until now. One
  /// `/v1/items/media-links` call fills it in place, and the subtitle tracks — configured
  /// at init, when the episode still had none — are rebuilt from what arrived.
  @MainActor
  private func resolveStreamLinksIfNeeded() async {
    // `fileURL == nil` rather than "files are empty": a downloaded episode plays from
    // disk without any links, and must not spend a request to learn that.
    guard watchMode == .media,
          fileURL == nil,
          let episode = playItem as? Episode else { return }
    await MediaLinksResolver.shared.fill(episode, using: contentService)
    configureSubtitles()
  }

  /// Media masters route through `HLSMasterResourceLoader` so the Audio picker gets
  /// real dub names; trailers, downloaded files and items without track metadata play
  /// their URL directly.
  private func playbackAsset(for source: URL) -> AVURLAsset {
    guard watchMode == .media,
          !playItem.audioTracks.isEmpty,
          let scheme = source.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          let masked = HLSMasterResourceLoader.maskedURL(for: source) else {
      return AVURLAsset(url: source)
    }
    let loader = HLSMasterResourceLoader(remote: source, tracks: playItem.audioTracks)
    masterLoader = loader
    let asset = AVURLAsset(url: masked)
    asset.resourceLoader.setDelegate(loader, queue: Self.loaderQueue)
    return asset
  }

  /// Keeps `playbackState` honest: ready when the item is, failed — with the reason —
  /// when it dies, either before the first frame or mid-stream.
  private func observePlaybackState(of item: AVPlayerItem) {
    playbackState = .preparing
    statusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
      DispatchQueue.main.async {
        guard let self else { return }
        switch item.status {
        case .readyToPlay:
          self.playbackState = .ready
          self.applyPendingSeekIfPossible()
          // Nothing is said to the server until there is something to play. The view
          // used to ask on appear — before the player had an item, on a title the
          // viewer had not started.
          Task { await self.fetchWatchMark() }
        case .failed:
          self.playbackState = .failed(Self.failureMessage(for: item))
        default:
          break
        }
      }
    }
    playbackFailureObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
    ) { [weak self] note in
      let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
      self?.playbackState = .failed(error?.localizedDescription ?? "Couldn't Load".localized)
    }
  }

  private static func failureMessage(for item: AVPlayerItem) -> String {
    if let error = item.error {
      return error.localizedDescription
    }
    if let comment = item.errorLog()?.events.last?.errorComment {
      return comment
    }
    return "Couldn't Load".localized
  }

  deinit {
    cueLoadTasks.forEach { $0.cancel() }
    if let cueObserverToken {
      player.removeTimeObserver(cueObserverToken)
    }
    if let playbackFailureObserver {
      NotificationCenter.default.removeObserver(playbackFailureObserver)
    }
    if let endOfPlaybackObserver {
      NotificationCenter.default.removeObserver(endOfPlaybackObserver)
    }
#if os(tvOS)
    audioReadyObservation?.invalidate()
#endif
  }

  /// Stops the current stream so a new `PlaybackSession` request can take over the
  /// single shared player without two AVPlayers competing.
  func tearDownForReplacement() {
    player.pause()
    player.replaceCurrentItem(with: nil)
    cueLoadTasks.forEach { $0.cancel() }
    cueLoadTasks = []
    if let cueObserverToken {
      player.removeTimeObserver(cueObserverToken)
      self.cueObserverToken = nil
    }
    if let playbackFailureObserver {
      NotificationCenter.default.removeObserver(playbackFailureObserver)
      self.playbackFailureObserver = nil
    }
    if let endOfPlaybackObserver {
      NotificationCenter.default.removeObserver(endOfPlaybackObserver)
      self.endOfPlaybackObserver = nil
    }
#if os(tvOS)
    audioReadyObservation?.invalidate()
    audioReadyObservation = nil
#endif
    isPlaying = false
    playbackState = .preparing
  }

  /// Playing to the very end marks the title watched (see `markFinished`).
  private func observeEndOfPlayback(of item: AVPlayerItem) {
    guard watchMode == .media else { return }
    if let endOfPlaybackObserver {
      NotificationCenter.default.removeObserver(endOfPlaybackObserver)
    }
    endOfPlaybackObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
    ) { [weak self] _ in
      self?.markFinished()
    }
  }

  // MARK: - Subtitles

  /// Nothing to pick from on a trailer, or on an item the API gave no tracks for.
  var canChooseSubtitles: Bool {
    watchMode == .media && !subtitleTracks.isEmpty
  }

  /// The tracks to open with: what was picked last time on this title, otherwise the
  /// defaults from Profile → Playback.
  ///
  /// tvOS only. Everywhere else the system player lists the HLS subtitle renditions from
  /// the master itself and renders them, so downloading sidecar SRT there would fetch
  /// files nothing draws.
  private func configureSubtitles() {
#if os(tvOS)
    guard watchMode == .media else { return }
    subtitleTracks = SubtitleSelector.tracks(in: playItem.subtitles)
    let remembered = SubtitleTrackMemory.choice(for: playItem.metadata.id)
    let selection = SubtitleSelector.selection(in: subtitleTracks, remembered: remembered)
    apply(selection, remember: false)
#endif
  }

  /// Picking a track is also a statement about the next episode, so every change from
  /// the picker is written down.
  ///
  /// Turning the first line off turns the pair off: a second line on its own, with the
  /// first row reading "Off", is a screen that lies about what it is showing.
  func select(primary track: SubtitleTrack?) {
    guard let track else {
      apply(SubtitleSelector.Selection(primary: nil, secondary: nil), remember: true)
      return
    }
    var selection = SubtitleSelector.Selection(primary: track, secondary: secondaryTrack)
    if selection.secondary == track { selection.secondary = nil }
    apply(selection, remember: true)
  }

  func select(secondary track: SubtitleTrack?) {
    var selection = SubtitleSelector.Selection(primary: primaryTrack, secondary: track)
    if selection.primary == track { selection.primary = nil }
    if selection.primary == nil {
      selection.primary = selection.secondary
      selection.secondary = nil
    }
    apply(selection, remember: true)
  }

  private func apply(_ selection: SubtitleSelector.Selection, remember: Bool) {
    cueLoadTasks.forEach { $0.cancel() }
    cueLoadTasks = []

    primaryTrack = selection.primary
    secondaryTrack = selection.secondary
    cues = []
    secondaryCues = []
    activeCue = nil
    activeSecondaryCue = nil
    lastCue = nil
    subtitlesEnabled = false

    if remember {
      SubtitleTrackMemory.remember(SubtitleChoice(primary: selection.primary?.reference,
                                                  secondary: selection.secondary?.reference),
                                   for: playItem.metadata.id)
    }

    // The transport-bar menu is the only place these tracks are shown on tvOS, so its
    // checkmarks have to move the instant the selection does.
#if os(tvOS)
    rebuildTransportBarMenus()
#endif

    guard let primary = selection.primary else {
      disableSystemLegibleSelection()
      return
    }

    if let url = sidecarURL(for: primary) {
      cueLoadTasks.append(Task { [weak self] in
        await self?.loadSidecarSubtitles(from: url, shift: primary.subtitle.shift, isPrimary: true)
      })
    } else {
      // Stream survey: every kino.pub subtitle is a sidecar SRT (embed × 0). No HLS
      // legible fallback — selecting an embedded track would only mis-fire.
      Logger.app.debug("Primary subtitle has no sidecar URL; overlay stays empty")
    }

    if let secondary = selection.secondary, let url = sidecarURL(for: secondary) {
      cueLoadTasks.append(Task { [weak self] in
        await self?.loadSidecarSubtitles(from: url, shift: secondary.subtitle.shift, isPrimary: false)
      })
    }
  }

  private func sidecarURL(for track: SubtitleTrack) -> URL? {
    guard track.hasSidecar else { return nil }
    return URL(string: track.url)
  }

  private func loadSidecarSubtitles(from url: URL, shift: Int, isPrimary: Bool) async {
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard let content = String(data: data, encoding: .utf8)
              ?? String(data: data, encoding: .isoLatin1) else {
        Logger.app.error("Failed to decode subtitle file at \(url.absoluteString)")
        return
      }
      let parsed = SubtitleCueParser.parse(content, shiftMilliseconds: shift)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        if isPrimary {
          self.cues = parsed
          self.subtitlesEnabled = !parsed.isEmpty
          // Avoid double captions if the stream also has embedded tracks.
          self.disableSystemLegibleSelection()
        } else {
          self.secondaryCues = parsed
        }
        Logger.app.debug("Loaded \(parsed.count) subtitle cues (primary: \(isPrimary))")
      }
    } catch {
      Logger.app.error("Failed to load subtitles: \(error)")
    }
  }

  private func disableSystemLegibleSelection() {
    guard let item = player.currentItem else { return }
    Task { @MainActor in
      guard let group = try? await item.asset.loadMediaSelectionGroup(for: .legible) else { return }
      item.select(nil, in: group)
    }
  }

  private func addCueTimeObserver() {
    let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    cueObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      guard let self else { return }
      let seconds = time.seconds.isFinite ? time.seconds : 0
      self.currentPlaybackTime = seconds
      guard self.subtitlesEnabled, !self.cues.isEmpty else {
        if self.activeCue != nil { self.activeCue = nil }
        if self.activeSecondaryCue != nil { self.activeSecondaryCue = nil }
        return
      }
      let cue = SubtitleCueParser.cue(at: seconds, in: self.cues)
      if cue != self.activeCue {
        self.activeCue = cue
        if let cue {
          self.lastCue = cue
        }
      }
      guard !self.secondaryCues.isEmpty else {
        if self.activeSecondaryCue != nil { self.activeSecondaryCue = nil }
        return
      }
      // The two tracks have their own timings, so the second line is looked up on its
      // own rather than paired with the first.
      let secondary = SubtitleCueParser.cue(at: seconds, in: self.secondaryCues)
      if secondary != self.activeSecondaryCue {
        self.activeSecondaryCue = secondary
      }
    }
  }

  // MARK: - Watch marks

  /// Local resume on every observer tick (~10s); server `marktime` every ~30s of progress.
  func saveWatchMark(time: TimeInterval) {
    guard watchMode == .media, canReportWatching else { return }

    let duration = player.currentItem?.duration.seconds ?? 0
    AppContext.shared.localProgressStore.recordProgress(
      mediaId: playItem.metadata.id,
      position: time,
      duration: duration,
      season: playItem.metadata.season,
      episode: playItem.metadata.video
    )

    // Position-based cadence so a scrub still re-marks after ~30s of movement.
    let due = lastServerMarkPosition == 0
      ? time >= Self.serverMarkInterval
      : abs(time - lastServerMarkPosition) >= Self.serverMarkInterval
    guard due else { return }
    lastServerMarkPosition = time

    Task.detached(priority: .utility) { [unowned self] in
      do {
        try await self.actionsService.markWatch(id: playItem.metadata.id,
                                                time: Int(time), video: playItem.metadata.video,
                                                season: playItem.metadata.season)
      } catch {
        Logger.app.error("Failed to save watch mark: \(error)")
      }
    }
  }

  /// Reaching the end marks the title watched. kino.pub derives watched status from the position
  /// reported via `marktime`, so we send one final marktime at the full duration. Locally we
  /// keep a finished tombstone (not a clear) so Home can hide a film / step a series without
  /// invalidating the rest of the Home cache.
  private func markFinished() {
    guard watchMode == .media, canReportWatching else { return }
    let duration = player.currentItem?.duration.seconds ?? 0
    guard duration.isFinite, duration > 0 else { return }
    AppContext.shared.localProgressStore.recordFinished(
      mediaId: playItem.metadata.id,
      duration: duration,
      season: playItem.metadata.season,
      episode: playItem.metadata.video
    )
    Task.detached(priority: .utility) { [weak self] in
      guard let self else { return }
      do {
        try await self.actionsService.markWatch(id: self.playItem.metadata.id,
                                                time: Int(duration),
                                                video: self.playItem.metadata.video,
                                                season: self.playItem.metadata.season)
      } catch {
        Logger.app.error("Failed to mark finished: \(error)")
      }
    }
  }

  /// Pick up where the title was left off. There is no prompt any more: the remembered
  /// time is where playback resumes, and the transport bar's own scrubber is right there
  /// for anyone who meant to start over.
  /// True when we know which **item** is playing. An episode that reached the player
  /// without its series id would otherwise be reported under its media id, which the
  /// API answers 404 to — and would silently write onto a different title if that
  /// number happened to be a real item id.
  private var canReportWatching: Bool {
    guard playItem.metadata.isResolved else {
      Logger.app.error(
        "watching skipped: unresolved item id for video=\(self.playItem.metadata.video ?? -1) season=\(self.playItem.metadata.season ?? -1)"
      )
      return false
    }
    return true
  }

  /// The resume point, asked for **once playback has actually started**. It used to be
  /// requested from `onAppear`, which asked the server about a title the viewer had not
  /// begun watching and often before the player had an item at all.
  @MainActor
  func fetchWatchMark() async {
    guard watchMode == .media, canReportWatching, !didFetchWatchMark else { return }
    didFetchWatchMark = true

    var remoteContinueTime: TimeInterval = 0
    do {
      watchMark = try await actionsService.fetchWatchMark(id: playItem.metadata.id,
                                                          video: playItem.metadata.video,
                                                          season: playItem.metadata.season)
      if let watchMark {
        remoteContinueTime = watchMark.item.videos?.first?.time
          ?? watchMark.item.seasons?.first?.episodes.first?.time
          ?? 0
      }
    } catch {
      Logger.app.error("Failed to fetch watch mark: \(error)")
    }

    let localContinueTime = AppContext.shared.localProgressStore
      .entry(forId: playItem.metadata.id,
             season: playItem.metadata.season,
             episode: playItem.metadata.video)?
      .position ?? 0

    let best = max(remoteContinueTime, localContinueTime)
    if best > 0 {
      seek(to: best)
    }
  }

  /// Seek now if the item is ready; otherwise remember the time until `readyToPlay`.
  /// Seeking a not-yet-ready (or not-yet-set) item is silently dropped.
  private func seek(to time: TimeInterval) {
    pendingResumeTime = time
    applyPendingSeekIfPossible()
  }

  private func applyPendingSeekIfPossible() {
    guard let time = pendingResumeTime else { return }
    let seekTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    if player.currentItem?.status == .readyToPlay {
      player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
      pendingResumeTime = nil
      seekObservation?.invalidate()
      seekObservation = nil
      return
    }
    guard player.currentItem != nil, seekObservation == nil else { return }
    seekObservation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard item.status == .readyToPlay else { return }
      self?.applyPendingSeekIfPossible()
    }
  }

  // MARK: - Title / subtitle

  /// The film or series name for the transport bar's info panel. The `PlayableItem`
  /// protocol doesn't carry a display name, so we recover it from the concrete type —
  /// the only place the name actually lives.
  var displayTitle: String? {
    if let media = playItem as? MediaItem {
      let name = media.localizedTitle
      return name.isEmpty ? nil : name
    }
    if let download = playItem as? DownloadMeta {
      return download.localizedTitle.isEmpty ? nil : download.localizedTitle
    }
    if let episode = playItem as? Episode {
      // The item page fills `seriesTitle` in before handing the episode to the player;
      // a bare `Episode` from elsewhere falls back to its own title, the best we have.
      if let seriesTitle = episode.seriesTitle, !seriesTitle.isEmpty {
        return seriesTitle
      }
      return episode.fixedTitle
    }
    return nil
  }

  /// "Season 2, Episode 5 — <episode title>" for a series episode; nothing for a movie.
  var displaySubtitle: String? {
    guard let episode = playItem as? Episode else { return nil }
    var parts: [String] = []
    if let season = episode.seasonNumber {
      parts.append("\("Season".localized) \(season)")
    }
    parts.append("\("Episode".localized) \(episode.number)")
    let line = parts.joined(separator: ", ")
    // The title line already shows the episode name, so only append it when it adds
    // something the "Episode N" label doesn't already say.
    let epTitle = episode.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !epTitle.isEmpty, epTitle != displayTitle {
      return "\(line) — \(epTitle)"
    }
    return line
  }

}

#if os(iOS) || os(tvOS)

// MARK: - Now Playing metadata

/// `AVPlayerItem.externalMetadata` feeds the system player's info panel (tvOS), the
/// iOS 12.2+ system player / Control Center / lock screen, and AirPlay — everywhere but
/// macOS, which has no `externalMetadata` and carries the title on the window title bar
/// instead (see the customization-surface table in player-and-media.md).
extension PlayerManager {

  func configureExternalMetadata() {
    guard let item = player.currentItem else { return }
    var metadata: [AVMetadataItem] = []
    if let title = displayTitle {
      metadata.append(makeMetadataItem(.commonIdentifierTitle, value: title))
    }
    if let subtitle = displaySubtitle {
      metadata.append(makeMetadataItem(.iTunesMetadataTrackSubTitle, value: subtitle))
    }
    if let media = playItem as? MediaItem {
      if !media.plot.isEmpty {
        metadata.append(makeMetadataItem(.commonIdentifierDescription, value: media.plot))
      }
      let genreNames = media.genres.compactMap(\.title).filter { !$0.isEmpty }
      if !genreNames.isEmpty {
        metadata.append(makeMetadataItem(.commonIdentifierType, value: genreNames.joined(separator: ", ")))
      }
      // Poster artwork for the Info panel / Control Center / Apple TV home screen.
      let posterURL = [media.posters.big, media.posters.medium, media.posters.small]
        .first { !$0.isEmpty }
        .flatMap(URL.init(string:))
      if let posterURL {
        Task { [weak self] in
          await self?.attachArtwork(from: posterURL, to: item, base: metadata)
        }
      }
    }
    item.externalMetadata = metadata
  }

  private func attachArtwork(from url: URL, to item: AVPlayerItem, base: [AVMetadataItem]) async {
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard !data.isEmpty else { return }
      let artwork = AVMutableMetadataItem()
      artwork.identifier = .commonIdentifierArtwork
      artwork.value = data as NSData
      artwork.dataType = kCMMetadataBaseDataType_JPEG as String
      artwork.extendedLanguageTag = "und"
      let next = base + [artwork]
      await MainActor.run {
        item.externalMetadata = next
      }
    } catch {
      Logger.app.debug("Player artwork metadata skipped: \(error.localizedDescription)")
    }
  }

  private func makeMetadataItem(_ identifier: AVMetadataIdentifier, value: String) -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.identifier = identifier
    item.value = value as NSString
    item.extendedLanguageTag = "und"
    return item
  }

}

#endif

#if os(tvOS)

// MARK: - tvOS transport bar

extension PlayerManager {

  /// Hand the system player screen everything it needs: the title/subtitle for the info
  /// panel, and the Subtitles menu for the transport bar. Called from the
  /// `UIViewControllerRepresentable` once AVKit has made the controller.
  func attach(to controller: AVPlayerViewController) {
    playerViewController = controller
    configureExternalMetadata()
    hideSystemSubtitlePicker(on: controller)
    if player.currentItem != nil {
      configureDefaultAudioWhenReady()
    }
    rebuildTransportBarMenus()
  }

  /// The HLS legible group makes AVKit draw its own Subtitles control, so without this the
  /// transport bar shows two — ours (dual tracks + sidecar SRT) and the system's. Emptying
  /// the allowed-languages list removes the system one.
  ///
  /// Safe to drop here because kino.pub ships every subtitle as a sidecar SRT and the HLS
  /// subtitle renditions are just its own WebVTT copies of those same files (Stream survey:
  /// srt × 189, embed × 0, CC × 0) — so nothing the system picker could reach is missing
  /// from ours. This only hides the picker UI.
  private func hideSystemSubtitlePicker(on controller: AVPlayerViewController) {
    controller.allowedSubtitleOptionLanguages = []
  }

  // MARK: Audio

  /// AVFoundation's own default is "first rendition in the system language", which on a
  /// kino.pub HLS stream lands on an arbitrary Russian dub. We wait for the renditions to
  /// publish, then pick a good one — or the user's remembered pick — instead.
  private func configureDefaultAudioWhenReady() {
    guard watchMode == .media, let item = player.currentItem else { return }
    if item.status == .readyToPlay {
      applyAudibleGroup(from: item)
      return
    }
    audioReadyObservation?.invalidate()
    audioReadyObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard item.status == .readyToPlay else { return }
      DispatchQueue.main.async {
        self?.applyAudibleGroup(from: item)
      }
    }
  }

  private func applyAudibleGroup(from item: AVPlayerItem) {
    guard audibleGroup == nil else { return }
    Task { @MainActor in
      guard self.audibleGroup == nil,
            let group = try? await item.asset.loadMediaSelectionGroup(for: .audible) else { return }
      self.audibleGroup = group

      if !self.didChooseDefaultAudio {
        self.didChooseDefaultAudio = true
        let remembered = AudioTrackMemory.choice(for: self.playItem.metadata.id)
        let chosen = remembered.flatMap { name in
          group.options.first { $0.kinopubTrackName == name }
        } ?? AudioTrackRanker.best(in: group.options)
        if let chosen {
          item.select(chosen, in: group)
          // Seed the persist baseline with what we opened on, so the polling write only
          // fires once the user actually switches away from this — the auto-pick itself is
          // not a "choice" worth remembering as one.
          self.lastPersistedAudioName = chosen.kinopubTrackName
        }
      }
      self.rebuildTransportBarMenus()
    }
  }

  /// The audio track showing right now, whether we auto-picked it or the user chose it in
  /// the system picker. Read off the item's live selection rather than tracked by us.
  private var currentAudioOption: AVMediaSelectionOption? {
    guard let item = player.currentItem, let group = audibleGroup else { return nil }
    return item.currentMediaSelection.selectedMediaOption(in: group)
  }

  /// The system Audio picker leaves no delegate callback to hang "remember this dub" off,
  /// so we poll: the watch-mark tick (every 10s) is a fine cadence for persisting a track
  /// choice, and a change since last time gets written down for the next episode.
  func persistAudioSelectionIfNeeded() {
    guard watchMode == .media, let option = currentAudioOption else { return }
    let name = option.kinopubTrackName
    guard name != lastPersistedAudioName else { return }
    lastPersistedAudioName = name
    AudioTrackMemory.remember(name, for: playItem.metadata.id)
  }

  // MARK: Menus

  /// Rebuild the custom menu from scratch. `UIMenu` is immutable, so tracking the current
  /// pick means handing AVKit a freshly-built array every time anything changes.
  ///
  /// Only Subtitles lives here. Audio is left to the system picker the HLS stream already
  /// gives the transport bar — a second, hand-rolled Audio menu next to it was the "two
  /// buttons" duplication. We still choose a sensible default and remember the user's pick
  /// (see `configureDefaultAudioWhenReady` / `persistAudioSelectionIfNeeded`); we just no
  /// longer draw our own control for it.
  func rebuildTransportBarMenus() {
    guard let controller = playerViewController else { return }
    var items: [UIMenuElement] = []
    if let subtitles = subtitlesMenu() { items.append(subtitles) }
    controller.transportBarCustomMenuItems = items
  }

  private func subtitlesMenu() -> UIMenu? {
    guard canChooseSubtitles else { return nil }
    let first = UIMenu(title: "First subtitles".localized,
                       options: .singleSelection,
                       children: subtitleActions(current: primaryTrack) { [weak self] track in
                         self?.select(primary: track)
                       })
    let second = UIMenu(title: "Second subtitles".localized,
                        options: .singleSelection,
                        children: subtitleActions(current: secondaryTrack) { [weak self] track in
                          self?.select(secondary: track)
                        })
    return UIMenu(title: "Subtitles".localized,
                  image: UIImage(systemName: "captions.bubble"),
                  children: [first, second])
  }

  private func subtitleActions(current: SubtitleTrack?,
                               pick: @escaping (SubtitleTrack?) -> Void) -> [UIAction] {
    let off = UIAction(title: "Off".localized,
                       state: current == nil ? .on : .off) { _ in pick(nil) }
    let tracks = subtitleTracks.map { track in
      UIAction(title: track.displayName,
               state: current == track ? .on : .off) { _ in pick(track) }
    }
    return [off] + tracks
  }

}

extension AVMediaSelectionOption {

  /// The rendition's `NAME=` from the master playlist — the label carrying dub kind and
  /// studio, which is the whole point of `HLSAudioLabeler`.
  ///
  /// Not `displayName`: for an HLS audio rendition AVFoundation derives that from the
  /// language and throws `NAME=` away, so every Russian dub of an item comes back as
  /// plain "Russian". Verified against a kino.pub master — a rendition renamed to
  /// "ZZPROBE-ONE" still reported `displayName == "Russian"` while the common metadata
  /// title carried the new name. Ranking or remembering a track by `displayName` picks
  /// between identical strings and lands on an arbitrary dub.
  var kinopubTrackName: String {
    let title = commonMetadata
      .first { $0.commonKey == .commonKeyTitle }?
      .stringValue?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let title, !title.isEmpty { return title }
    return displayName
  }
}

/// The user's manually chosen audio track, kept per title the same way subtitles are, so
/// the next episode opens with the same dub. The rendition's playlist name is the stable
/// handle — it carries the dub kind and studio.
enum AudioTrackMemory {
  private static let storageKey = "audioTrackChoices"

  static func choice(for itemID: Int, defaults: UserDefaults = .standard) -> String? {
    stored(defaults)[String(itemID)]
  }

  static func remember(_ displayName: String, for itemID: Int, defaults: UserDefaults = .standard) {
    var choices = stored(defaults)
    choices[String(itemID)] = displayName
    guard let data = try? JSONEncoder().encode(choices) else { return }
    defaults.set(data, forKey: storageKey)
  }

  private static func stored(_ defaults: UserDefaults) -> [String: String] {
    guard let data = defaults.data(forKey: storageKey),
          let choices = try? JSONDecoder().decode([String: String].self, from: data) else {
      return [:]
    }
    return choices
  }
}

/// Picks a sensible default audio rendition when nothing was remembered.
///
/// Same ladder as the detail-page Audio column (`AudioTracks`): preferred languages,
/// then A–Z, AD last within a language, kind (DUB → MVO → DVO → VO → AVO → Orig),
/// studio A–Z, more channels first. The rendition's playlist name carries kind and
/// studio; language comes from the option's locale / tag.
enum AudioTrackRanker {

  static func best(in options: [AVMediaSelectionOption],
                   preferredLanguages: [String] = Locale.preferredLanguages) -> AVMediaSelectionOption? {
    options.min { lhs, rhs in
      sortKey(lhs, preferredLanguages: preferredLanguages)
        < sortKey(rhs, preferredLanguages: preferredLanguages)
    }
  }

  private static func sortKey(_ option: AVMediaSelectionOption,
                              preferredLanguages: [String]) -> AudioTracks.SortKey {
    let name = option.kinopubTrackName
    let lang = languageCode(for: option)
    return AudioTracks.sortKey(
      lang: lang,
      typeTitle: name,
      author: AudioTracks.authorFromDisplayName(name),
      channels: AudioTracks.channelCount(fromLabel: name),
      isAudioDescription: option.hasMediaCharacteristic(.describesVideoForAccessibility),
      index: 0,
      preferredLanguages: preferredLanguages
    )
  }

  private static func languageCode(for option: AVMediaSelectionOption) -> String {
    if let code = option.locale?.language.languageCode?.identifier, !code.isEmpty {
      return code
    }
    let tag = option.extendedLanguageTag ?? ""
    if !tag.isEmpty { return tag }
    return option.kinopubTrackName
  }
}

#endif
