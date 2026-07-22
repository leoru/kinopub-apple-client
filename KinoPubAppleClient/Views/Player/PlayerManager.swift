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

enum WatchMode {
  case media
  case trailer
}

class PlayerManager: ObservableObject {

  @Published var isPlaying: Bool = false
  @Published var watchMark: WatchData?
  @Published var continueTime: TimeInterval?
  @Published var activeCue: SubtitleCue?
  @Published var activeSecondaryCue: SubtitleCue?
  @Published var lastCue: SubtitleCue?
  @Published var subtitlesEnabled: Bool = false
  @Published var currentPlaybackTime: TimeInterval = 0

  /// Every subtitle track this item offers, and the two that are showing.
  @Published private(set) var subtitleTracks: [SubtitleTrack] = []
  @Published private(set) var primaryTrack: SubtitleTrack?
  @Published private(set) var secondaryTrack: SubtitleTrack?

  lazy var player: AVPlayer = {
    guard let fileURL else {
      Logger.app.error("No playable URL for item \(self.playItem.id) in \(String(describing: self.watchMode)) mode")
      return AVPlayer()
    }
    return AVPlayer(url: fileURL)
  }()
  private var playerTimeObserver: PlayerTimeObserver?
  private var cueObserverToken: Any?
  private var playItem: any PlayableItem
  private var watchMode: WatchMode
  private var downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>
  private var rateObservation: NSKeyValueObservation?
  private var itemObservation: NSKeyValueObservation?
  private var actionsService: UserActionsService
  private var cues: [SubtitleCue] = []
  private var secondaryCues: [SubtitleCue] = []
  private var cueLoadTasks: [Task<Void, Never>] = []

  /// Optional on purpose: both of these used to force-unwrap, and `URL(string: "")`
  /// is nil — an item without a trailer link crashed the app on open.
  private var fileURL: URL? {
    switch watchMode {
    case .media:
      let downloadedFiles = downloadedFilesDatabase.readData()
      if let file = downloadedFiles?.filter({ $0.metadata.id == playItem.id }).first {
        return file.localFileURL
      }
      return URL(string: BestVideoQualityFinder.findBestURL(for: playItem.files))
    case .trailer:
      return playItem.trailerURL
    }
  }

  init(playItem: any PlayableItem,
       watchMode: WatchMode,
       downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>,
       actionsService: UserActionsService) {
    self.playItem = playItem
    self.watchMode = watchMode
    self.actionsService = actionsService
    self.downloadedFilesDatabase = downloadedFilesDatabase
    rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
      DispatchQueue.main.async {
        self?.isPlaying = player.rate > 0
      }
    }

    playerTimeObserver = PlayerTimeObserver(player: player, period: 10.0, timeUpdateHandler: { [weak self] time in
      self?.saveWatchMark(time: time)
    })

    addCueTimeObserver()
    configureSubtitles()
  }

  deinit {
    cueLoadTasks.forEach { $0.cancel() }
    if let cueObserverToken {
      player.removeTimeObserver(cueObserverToken)
    }
  }

  // MARK: - Subtitles

  /// Nothing to pick from on a trailer, or on an item the API gave no tracks for.
  var canChooseSubtitles: Bool {
    watchMode == .media && !subtitleTracks.isEmpty
  }

  /// The tracks to open with: what was picked last time on this title, otherwise the
  /// defaults from Profile → Playback.
  private func configureSubtitles() {
    guard watchMode == .media else { return }

    subtitleTracks = SubtitleSelector.tracks(in: playItem.subtitles)
    let remembered = SubtitleTrackMemory.choice(for: playItem.metadata.id)
    let selection = SubtitleSelector.selection(in: subtitleTracks, remembered: remembered)
    apply(selection, remember: false)
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
    // A pending embedded-track fallback belongs to the tracks being replaced; leaving it
    // armed turns an embedded English track back on under the new pick.
    itemObservation = nil

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

    guard let primary = selection.primary else {
      disableSystemLegibleSelection()
      return
    }

    if let url = sidecarURL(for: primary) {
      cueLoadTasks.append(Task { [weak self] in
        await self?.loadSidecarSubtitles(from: url, shift: primary.subtitle.shift, isPrimary: true)
      })
    } else {
      // Fallback: try an embedded HLS legible track once the item is ready.
      itemObservation = player.observe(\.currentItem, options: [.new, .initial]) { [weak self] _, _ in
        self?.selectEmbeddedEnglishTrackIfNeeded()
      }
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
      guard isPrimary, !Task.isCancelled else { return }
      await MainActor.run {
        self.selectEmbeddedEnglishTrackIfNeeded()
      }
    }
  }

  private func selectEmbeddedEnglishTrackIfNeeded() {
    guard cues.isEmpty else { return }
    guard let item = player.currentItem else { return }
    guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }

    let options = group.options.filter { option in
      let langs = option.extendedLanguageTag?.lowercased() ?? ""
      let name = option.displayName
      let isEnglish = SubtitleSelector.isEnglish(langs)
        || SubtitleSelector.isEnglish(option.locale?.language.languageCode?.identifier ?? "")
        || name.lowercased().contains("english")
        || name.lowercased().hasPrefix("en")
      if !isEnglish { return false }
      if SubtitleSelector.isForcedDisplayName(name) { return false }
      if SubtitlePreferences.preferNonCCSubtitles && SubtitleSelector.looksLikeCCDisplayName(name) {
        return false
      }
      return true
    }

    if let option = options.first {
      item.select(option, in: group)
      DispatchQueue.main.async {
        self.subtitlesEnabled = true
      }
    }
  }

  private func disableSystemLegibleSelection() {
    guard let item = player.currentItem else { return }
    guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
    item.select(nil, in: group)
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

  func saveWatchMark(time: TimeInterval) {
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

  func fetchWatchMark() async {
    do {
      watchMark = try await actionsService.fetchWatchMark(id: playItem.metadata.id, video: playItem.metadata.video, season: playItem.metadata.season)
      if let watchMark {
        let remoteContinueTime = watchMark.item.videos?.first?.time ?? watchMark.item.seasons?.first?.episodes.first?.time
        self.continueTime = remoteContinueTime ?? 0 > 0 ? remoteContinueTime : nil
      }
    } catch {
      Logger.app.error("Failed to fetch watch mark: \(error)")
    }
  }

  // MARK: - Continue watching

  func seekToContinueWatching() {
    guard let continueTime else {
      return
    }

    let seekTime = CMTime(seconds: continueTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    player.seek(to: seekTime)

    self.continueTime = nil
  }

  func cancelContinueWatching() {
    self.continueTime = nil
  }

}
