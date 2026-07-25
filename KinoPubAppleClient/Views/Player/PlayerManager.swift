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

  let player = AVPlayer()
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
  private var didPreparePlayback = false

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
#if os(tvOS)
      self?.persistAudioSelectionIfNeeded()
#endif
    })

    addCueTimeObserver()
    configureSubtitles()
  }

  /// Loads the playable URL into `player`, rewriting the HLS master so AUDIO `NAME`s
  /// carry dub kind + studio. Safe to call more than once; only the first run does work.
  @MainActor
  func preparePlayback() async {
    guard !didPreparePlayback else { return }
    didPreparePlayback = true

    guard let source = fileURL else {
      Logger.app.error("No playable URL for item \(self.playItem.id) in \(String(describing: self.watchMode)) mode")
      return
    }

    let url = await Self.resolvedPlaybackURL(source: source,
                                             watchMode: watchMode,
                                             tracks: playItem.audioTracks)
    let item = AVPlayerItem(url: url)
    player.replaceCurrentItem(with: item)
#if os(tvOS)
    audibleGroup = nil
    didChooseDefaultAudio = false
    configureExternalMetadata()
    configureDefaultAudioWhenReady()
    rebuildTransportBarMenus()
#endif
  }

  /// Prefer a locally rewritten master with real dub names; fall back to the CDN URL.
  private static func resolvedPlaybackURL(source: URL,
                                          watchMode: WatchMode,
                                          tracks: [AudioTrackInfo]) async -> URL {
    guard watchMode == .media,
          !tracks.isEmpty,
          let scheme = source.scheme?.lowercased(),
          scheme == "http" || scheme == "https" else {
      return source
    }
    do {
      return try await HLSAudioLabeler.labeledMasterURL(from: source, tracks: tracks)
    } catch {
      Logger.app.error("HLS audio relabel failed, playing CDN master: \(error.localizedDescription)")
      return source
    }
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
  /// from ours. This only hides the picker UI; the fallback that programmatically selects
  /// an embedded English legible track (`selectEmbeddedEnglishTrackIfNeeded`) is unaffected.
  private func hideSystemSubtitlePicker(on controller: AVPlayerViewController) {
    controller.allowedSubtitleOptionLanguages = []
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
        // Seed the persist baseline with what we opened on, so the polling write only
        // fires once the user actually switches away from this — the auto-pick itself is
        // not a "choice" worth remembering as one.
        lastPersistedAudioName = chosen.displayName
      }
    }
    rebuildTransportBarMenus()
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
    let name = option.displayName
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
/// Same ladder as the detail-page Audio column (`AudioTracks`): preferred languages,
/// then A–Z, AD last within a language, kind (DUB → MVO → DVO → VO → AVO → Orig),
/// studio A–Z, more channels first. The option's display name carries kind and studio;
/// language comes from the option's locale / tag.
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
    let name = option.displayName
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
    return option.displayName
  }
}

#endif
