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

enum WatchMode {
  case media
  case trailer
}

class PlayerManager: ObservableObject {

  @Published var isPlaying: Bool = false
  @Published var watchMark: WatchData?
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
#endif

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
#if os(tvOS)
    audioReadyObservation?.invalidate()
#endif
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

  /// Pick up where the title was left off. There is no prompt any more: the remembered
  /// time is where playback resumes, and the transport bar's own scrubber is right there
  /// for anyone who meant to start over.
  func fetchWatchMark() async {
    do {
      watchMark = try await actionsService.fetchWatchMark(id: playItem.metadata.id, video: playItem.metadata.video, season: playItem.metadata.season)
      if let watchMark {
        let remoteContinueTime = watchMark.item.videos?.first?.time ?? watchMark.item.seasons?.first?.episodes.first?.time
        if let resume = remoteContinueTime, resume > 0 {
          seek(to: resume)
        }
      }
    } catch {
      Logger.app.error("Failed to fetch watch mark: \(error)")
    }
  }

  private func seek(to time: TimeInterval) {
    let seekTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    player.seek(to: seekTime)
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

#if os(tvOS)

// MARK: - tvOS transport bar

extension PlayerManager {

  /// Hand the system player screen everything it needs: the title/subtitle for the info
  /// panel, and the Subtitles + Audio menus for the transport bar. Called from the
  /// `UIViewControllerRepresentable` once AVKit has made the controller.
  func attach(to controller: AVPlayerViewController) {
    playerViewController = controller
    configureExternalMetadata()
    configureDefaultAudioWhenReady()
    rebuildTransportBarMenus()
  }

  private func configureExternalMetadata() {
    guard let item = player.currentItem else { return }
    var metadata: [AVMetadataItem] = []
    if let title = displayTitle {
      metadata.append(makeMetadataItem(.commonIdentifierTitle, value: title))
    }
    if let subtitle = displaySubtitle {
      metadata.append(makeMetadataItem(.iTunesMetadataTrackSubTitle, value: subtitle))
    }
    item.externalMetadata = metadata
  }

  private func makeMetadataItem(_ identifier: AVMetadataIdentifier, value: String) -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.identifier = identifier
    item.value = value as NSString
    item.extendedLanguageTag = "und"
    return item
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
    guard audibleGroup == nil,
          let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
    audibleGroup = group

    if !didChooseDefaultAudio {
      didChooseDefaultAudio = true
      let remembered = AudioTrackMemory.choice(for: playItem.metadata.id)
      let chosen = remembered.flatMap { name in
        group.options.first { $0.displayName == name }
      } ?? AudioTrackRanker.best(in: group.options)
      if let chosen {
        item.select(chosen, in: group)
      }
    }
    rebuildTransportBarMenus()
  }

  private func selectAudio(_ option: AVMediaSelectionOption) {
    guard let item = player.currentItem, let group = audibleGroup else { return }
    item.select(option, in: group)
    AudioTrackMemory.remember(option.displayName, for: playItem.metadata.id)
    rebuildTransportBarMenus()
  }

  // MARK: Menus

  /// Rebuild both custom menus from scratch. `UIMenu` is immutable, so tracking the
  /// current pick means handing AVKit a freshly-built array every time anything changes.
  func rebuildTransportBarMenus() {
    guard let controller = playerViewController else { return }
    var items: [UIMenuElement] = []
    if let subtitles = subtitlesMenu() { items.append(subtitles) }
    if let audio = audioMenu() { items.append(audio) }
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

  private func audioMenu() -> UIMenu? {
    guard let group = audibleGroup, group.options.count > 1 else { return nil }
    let selected = player.currentItem?.currentMediaSelection.selectedMediaOption(in: group)
    let actions = group.options.map { option in
      UIAction(title: option.displayName,
               state: option == selected ? .on : .off) { [weak self] _ in
        self?.selectAudio(option)
      }
    }
    return UIMenu(title: "Audio".localized,
                  image: UIImage(systemName: "waveform"),
                  options: .singleSelection,
                  children: actions)
  }
}

/// The user's manually chosen audio track, kept per title the same way subtitles are, so
/// the next episode opens with the same dub. The option's `displayName` is the stable
/// handle — it carries the dub kind and studio, and it's what the menu shows.
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
/// kino.pub labels every dub in the option's display name — its kind (дубляж / многоголосый
/// / двухголосый / одноголосый / оригинал) and often the studio. We read that label and
/// rank Russian first, then by kind, then by channel count, then a named studio over an
/// anonymous one. Latin spellings are recognised alongside the Cyrillic ones.
enum AudioTrackRanker {

  static func best(in options: [AVMediaSelectionOption]) -> AVMediaSelectionOption? {
    options.max { lhs, rhs in rank(lhs) < rank(rhs) }
  }

  private struct Rank: Comparable {
    let isRussian: Bool
    let kind: Int
    let channels: Int
    let hasStudio: Bool

    static func < (l: Rank, r: Rank) -> Bool {
      if l.isRussian != r.isRussian { return !l.isRussian && r.isRussian }
      if l.kind != r.kind { return l.kind < r.kind }
      if l.channels != r.channels { return l.channels < r.channels }
      if l.hasStudio != r.hasStudio { return !l.hasStudio && r.hasStudio }
      return false
    }
  }

  private static func rank(_ option: AVMediaSelectionOption) -> Rank {
    let name = option.displayName.lowercased()
    let langTag = (option.extendedLanguageTag ?? "").lowercased()
    let langCode = option.locale?.language.languageCode?.identifier.lowercased() ?? ""
    return Rank(isRussian: isRussian(name: name, langTag: langTag, langCode: langCode),
                kind: kindScore(name),
                channels: channelScore(name),
                hasStudio: hasStudio(name))
  }

  private static func isRussian(name: String, langTag: String, langCode: String) -> Bool {
    if langCode == "ru" || langTag.hasPrefix("ru") { return true }
    return name.contains("рус") || name.contains("rus") || name.contains("russian")
  }

  /// Higher wins. Dubbing over a full cast over two voices over one; original is last so
  /// a lone Russian voice-over still beats the untranslated track.
  private static func kindScore(_ name: String) -> Int {
    if name.contains("дубляж") || name.contains("дублир")
        || name.contains("dubbed") || name.contains("dub") { return 5 }
    if name.contains("многоголос") || name.contains("multi") || name.contains("mvo") { return 4 }
    if name.contains("двухголос") || name.contains("two") || name.contains("dvo") { return 3 }
    if name.contains("одноголос") || name.contains("single") || name.contains("ovo") { return 2 }
    if name.contains("оригинал") || name.contains("original") { return 1 }
    return 0
  }

  /// Best-effort channel count read off the label ("5.1", "стерео", "mono").
  private static func channelScore(_ name: String) -> Int {
    if name.contains("7.1") { return 8 }
    if name.contains("5.1") { return 6 }
    if name.contains("2.0") || name.contains("стерео") || name.contains("stereo") { return 2 }
    if name.contains("mono") || name.contains("моно") { return 1 }
    return 2
  }

  /// A named studio usually appears in parentheses ("(LostFilm)"); an anonymous track
  /// has none. Not perfect, but it breaks ties toward the labelled release.
  private static func hasStudio(_ name: String) -> Bool {
    name.contains("(") && name.contains(")")
  }
}

#endif
