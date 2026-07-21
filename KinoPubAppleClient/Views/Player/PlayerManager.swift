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
  @Published var lastCue: SubtitleCue?
  @Published var subtitlesEnabled: Bool = false
  @Published var currentPlaybackTime: TimeInterval = 0

  lazy var player = AVPlayer(url: fileURL)
  private var playerTimeObserver: PlayerTimeObserver?
  private var cueObserverToken: Any?
  private var playItem: any PlayableItem
  private var watchMode: WatchMode
  private var downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>
  private var rateObservation: NSKeyValueObservation?
  private var itemObservation: NSKeyValueObservation?
  private var actionsService: UserActionsService
  private var cues: [SubtitleCue] = []
  private var selectedSubtitle: Subtitle?

  private var fileURL: URL {
    switch watchMode {
    case .media:
      let downloadedFiles = downloadedFilesDatabase.readData()
      if let file = downloadedFiles?.filter({ $0.metadata.id == playItem.id }).first {
        return file.localFileURL
      }
      return URL(string: BestVideoQualityFinder.findBestURL(for: playItem.files))!
    case .trailer:
      return URL(string: playItem.trailer?.url ?? "")!
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
    if let cueObserverToken {
      player.removeTimeObserver(cueObserverToken)
    }
  }

  // MARK: - Subtitles

  private func configureSubtitles() {
    guard watchMode == .media else { return }
    guard SubtitlePreferences.preferEnglishSubtitles else {
      subtitlesEnabled = false
      return
    }

    selectedSubtitle = SubtitleSelector.preferred(
      from: playItem.subtitles,
      preferNonCC: SubtitlePreferences.preferNonCCSubtitles
    )

    if let selectedSubtitle, let url = URL(string: selectedSubtitle.url), !selectedSubtitle.url.isEmpty {
      Task { [weak self] in
        await self?.loadSidecarSubtitles(from: url, shift: selectedSubtitle.shift)
      }
    } else {
      // Fallback: try embedded HLS legible track once the item is ready.
      itemObservation = player.observe(\.currentItem, options: [.new, .initial]) { [weak self] _, _ in
        self?.selectEmbeddedEnglishTrackIfNeeded()
      }
    }
  }

  private func loadSidecarSubtitles(from url: URL, shift: Int) async {
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard let content = String(data: data, encoding: .utf8)
              ?? String(data: data, encoding: .isoLatin1) else {
        Logger.app.error("Failed to decode subtitle file at \(url.absoluteString)")
        return
      }
      let parsed = SubtitleCueParser.parse(content, shiftMilliseconds: shift)
      await MainActor.run {
        self.cues = parsed
        self.subtitlesEnabled = !parsed.isEmpty
        // Avoid double captions if the stream also has embedded tracks.
        self.disableSystemLegibleSelection()
        Logger.app.debug("Loaded \(parsed.count) subtitle cues")
      }
    } catch {
      Logger.app.error("Failed to load subtitles: \(error)")
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
        return
      }
      let cue = SubtitleCueParser.cue(at: seconds, in: self.cues)
      if cue != self.activeCue {
        self.activeCue = cue
        if let cue {
          self.lastCue = cue
        }
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
