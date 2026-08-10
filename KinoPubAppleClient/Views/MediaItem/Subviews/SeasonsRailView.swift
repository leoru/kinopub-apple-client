//
//  SeasonsRailView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubMetadata

/// Season tabs over one continuous horizontal rail of every episode in the series —
/// S1E1 through the finale — the way the Apple TV app presents a show. Tabs scroll the
/// rail to that season's first episode rather than swapping the content out. Opens
/// scrolled to the first unfinished episode.
///
/// Focus rules (tvOS): the season tabs are a `focusSection` spanning the full width, so
/// geometric Up from any episode card lands on the tab strip (not empty space or a
/// random tab). `defaultFocus` parks on the selected season. Left/Right on tabs still
/// selects + scrolls when the season changes.
///
/// Section chrome (season tabs) stays hidden while the hero owns the page, so the
/// trailer/wide art isn't captioned by "Season 1" peeking under it; it fades in once
/// focus drops onto the rail and the backdrop blurs.
/// DESIGN: season-level "clear progress" → `UserActionsService.clearHistoryForSeason`
/// (`POST /v1/history/clear-for-season`). Episode hide/toggle-watched stay as they are.
struct SeasonsRailView: View {

  let seasons: [Season]
  let linkProvider: NavigationLinkProvider
  /// Filled into every episode handed to the player, so its transport bar can show the
  /// series name rather than just the episode's own title.
  let seriesTitle: String
  /// False while the hero/trailer is up — season tabs stay out of the way.
  var showsChrome: Bool = true
  /// Fired when any control in this rail takes focus, so the page can snap to the
  /// seasons "page" and stop the outer scroll from drifting between episodes/tabs.
  var onSectionFocused: (() -> Void)? = nil
#if os(tvOS)
  /// Bumped by the detail page when it flips from the hero onto this rail — we then
  /// park focus on the selected season tab so Play cannot reclaim the remote.
  var pageEntryToken: Int = 0
#endif
  var onHide: ((Episode, Season) -> Void)?
  var onToggleWatched: ((Episode, Season) -> Void)?
  /// Full TMDB season schedules keyed by season number — used to date kino episodes
  /// and to inject episodes that exist on TMDB but not yet on kino.pub.
  var seasonSchedules: [Int: [EpisodeSchedule]] = [:]
  /// Title-level metadata: drives the trailing missing/upcoming-season cards.
  var externalMetadata: TitleMetadata = TitleMetadata()
  /// Ask the model to fetch schedule for a season number (kino.pub season.number).
  var onSeasonVisible: ((Int) -> Void)? = nil

  @Environment(ErrorHandler.self) private var errorHandler
  @EnvironmentObject private var navigationState: NavigationState
  @Environment(\.openURL) private var openURL
  @Environment(\.dynamicTypeSize) private var typeSize
  @StateObject private var cardMenu = MediaCardMenuCoordinator()
  /// Measured rail width, so cards land on the same `ShelfMetrics` grid as every
  /// other landscape shelf (Continue Watching, History) rather than a fixed size.
  @State private var railWidth: CGFloat = SeasonsRailView.referenceWidth
  @State private var selectedSeasonID: Int?
  /// The episode `defaultFocus`/scroll should land on for the *currently selected*
  /// season. Regressed in `38c6d07` ("Episodes and seasons rail"): the original
  /// `c1bd46f` scrolled straight to the first-unseen episode's own anchor; that commit
  /// routed the initial jump through `selectSeason`, which only ever knew "that
  /// season's first episode" — so resuming a show mid-season correctly picked the right
  /// *season* tab but always landed on its episode 1. Tracked separately from
  /// `selectedSeasonID` because manual tab clicks/switches still want "season's first
  /// episode" (unchanged), only the initial resume jump wants the specific episode.
  @State private var seasonEntryEpisodeID: Int?
  @State private var didScrollToUnseen = false
  /// True while a tab-driven scroll is in flight, so a stray episode focus update
  /// doesn't yank the selected tab back mid-jump.
  @State private var isScrollingFromTab = false
  @FocusState private var focusedSeasonID: Int?
  @FocusState private var focusedEpisodeID: Int?

  private enum RailEntry: Identifiable {
    case playable(season: Season, episode: Episode, schedule: EpisodeSchedule?)
    /// On TMDB but not uploaded to kino.pub yet (or future air date).
    case unavailable(season: Season, schedule: EpisodeSchedule)
    /// Whole seasons between kino.pub's last and the next announced one — one dark
    /// info card instead of a row of untappable tabs.
    case missingSeasons(from: Int, to: Int, episodes: Int?, firstAir: Date?, lastAir: Date?)
    /// The next season with a known premiere date, ahead of everything kino.pub has.
    case upcomingSeason(number: Int, date: Date, poster: URL?)

    var id: Int {
      switch self {
      case .playable(_, let episode, _):
        return episode.id
      case .unavailable(let season, let schedule):
        // Negative synthetic id — outside kino.pub's positive media ids.
        return -(season.number * 1_000_000 + schedule.episodeNumber)
      case .missingSeasons(let from, let to, _, _, _):
        return -(2_000_000_000 + from * 1_000 + to)
      case .upcomingSeason(let number, _, _):
        return -(2_100_000_000 + number)
      }
    }

    var season: Season? {
      switch self {
      case .playable(let season, _, _), .unavailable(let season, _):
        return season
      case .missingSeasons, .upcomingSeason:
        return nil
      }
    }

    var episodeNumber: Int {
      switch self {
      case .playable(_, let episode, _): return episode.number
      case .unavailable(_, let schedule): return schedule.episodeNumber
      case .missingSeasons, .upcomingSeason: return .max
      }
    }

    var schedule: EpisodeSchedule? {
      switch self {
      case .playable(_, _, let schedule): return schedule
      case .unavailable(_, let schedule): return schedule
      case .missingSeasons, .upcomingSeason: return nil
      }
    }

    var isPlayable: Bool {
      if case .playable = self { return true }
      return false
    }
  }

  private var entries: [RailEntry] {
    let episodeEntries = seasons.flatMap { season -> [RailEntry] in
      let tmdb = seasonSchedules[season.number] ?? []
      let byNumber = Dictionary(uniqueKeysWithValues: tmdb.map { ($0.episodeNumber, $0) })
      let kinoNumbers = Set(season.episodes.map(\.number))

      var result: [RailEntry] = season.episodes.map { episode in
        .playable(season: season, episode: episode, schedule: byNumber[episode.number])
      }

      // Episodes TMDB knows about that kino.pub hasn't uploaded yet.
      let extras = tmdb
        .filter { !kinoNumbers.contains($0.episodeNumber) }
        .sorted { $0.episodeNumber < $1.episodeNumber }
        .map { RailEntry.unavailable(season: season, schedule: $0) }

      result.append(contentsOf: extras)
      result.sort { $0.episodeNumber < $1.episodeNumber }
      return result
    }
    return episodeEntries + trailingCards
  }

  /// What sits past kino.pub's last season: skipped seasons as one dark card, then
  /// the announced season with its premiere date — never as dead season tabs.
  private var trailingCards: [RailEntry] {
    guard let lastKino = seasons.last,
          let next = externalMetadata.nextEpisode,
          let date = next.airDate, date > Date(),
          next.seasonNumber > (lastKino.titleSeasonNumber ?? lastKino.number)
    else { return [] }

    let lastKinoNumber = lastKino.titleSeasonNumber ?? lastKino.number
    var cards: [RailEntry] = []

    let gap = externalMetadata.seasonSummaries
      .filter { $0.seasonNumber > lastKinoNumber && $0.seasonNumber < next.seasonNumber }
    if let first = gap.first, let last = gap.last {
      let episodes = gap.reduce(0) { $0 + ($1.episodeCount ?? 0) }
      cards.append(.missingSeasons(from: first.seasonNumber,
                                   to: last.seasonNumber,
                                   episodes: episodes > 0 ? episodes : nil,
                                   firstAir: first.airDate,
                                   lastAir: last.airDate))
    }

    let poster = externalMetadata.seasonSummaries
      .first { $0.seasonNumber == next.seasonNumber }?.poster
    cards.append(.upcomingSeason(number: next.seasonNumber, date: date, poster: poster))
    return cards
  }

  private var selectedSeason: Season? {
    seasons.first { $0.id == selectedSeasonID } ?? seasons.first
  }

  // MARK: - Metrics (shared with every other landscape shelf)

  private var metrics: ShelfMetrics {
    .landscape(width: railWidth, typeSize: typeSize)
  }

  private var cardWidth: CGFloat {
    metrics.cardWidth(in: railWidth)
  }

  private var stillHeight: CGFloat {
    cardWidth / CardAspect.landscape.ratio
  }

  /// First unfinished playable episode walking seasons in order, else the very first rail item.
  private var firstUnseen: RailEntry? {
    entries.first {
      if case .playable(_, let episode, _) = $0 { return episode.watched == 0 }
      return false
    } ?? entries.first
  }

  /// Episode to land on when Down crosses from the season tabs into the rail — the
  /// tracked resume/entry episode when there is one, else that season's first.
  private var firstEpisodeInSelectedSeason: Int? {
    if let seasonEntryEpisodeID, entries.contains(where: { $0.id == seasonEntryEpisodeID }) {
      return seasonEntryEpisodeID
    }
    if let selectedSeasonID,
       let first = entries.first(where: { $0.season?.id == selectedSeasonID }) {
      return first.id
    }
    return entries.first?.id
  }

  var body: some View {
    ScrollViewReader { proxy in
      VStack(alignment: .leading, spacing: showsChrome ? 2 : 0) {
        if showsChrome {
          seasonTabs(proxy: proxy)
            .transition(.opacity)
        }

        episodeRail
      }
      .animation(.easeOut(duration: 0.25), value: showsChrome)
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.width
      } action: { width in
        if width > 0 { railWidth = width }
      }
      .onAppear {
        if selectedSeasonID == nil {
          selectedSeasonID = firstUnseen?.season?.id ?? seasons.first?.id
        }
      }
      .task {
        await scrollToFirstUnseen(proxy: proxy)
      }
      .task {
        cardMenu.bind(errorHandler: errorHandler)
        await cardMenu.refreshFolders()
      }
      .mediaCardNewFolderAlert(cardMenu)
#if os(tvOS)
      .onChange(of: focusedSeasonID) { _, seasonID in
        if seasonID != nil { onSectionFocused?() }
        // Left/Right onto a *different* tab selects + scrolls. Re-focusing the already
        // selected tab leaves the rail frozen.
        guard let seasonID, seasonID != selectedSeasonID else { return }
        selectSeason(seasonID, proxy: proxy, animated: true)
      }
      .onChange(of: focusedEpisodeID) { _, episodeID in
        if episodeID != nil { onSectionFocused?() }
        guard !isScrollingFromTab,
              let episodeID,
              let entry = entries.first(where: { $0.id == episodeID }),
              let season = entry.season else { return }
        selectedSeasonID = season.id
      }
      .onChange(of: pageEntryToken) { _, _ in
        focusedSeasonID = selectedSeasonID ?? seasons.first?.id
      }
#endif
    }
  }

  // MARK: - Season tabs

  private func seasonTabs(proxy: ScrollViewProxy) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: Self.tabSpacing) {
        ForEach(seasons) { season in
          Button {
            // Enter / click only moves the rail when the season actually changes.
            guard season.id != selectedSeasonID else { return }
            selectSeason(season.id, proxy: proxy, animated: true)
          } label: {
            Text(Self.seasonTitle(season))
              .font(Self.tabFont)
          }
#if os(tvOS)
          .focused($focusedSeasonID, equals: season.id)
#endif
          .buttonStyle(SeasonTabButtonStyle(isSelected: season.id == selectedSeason?.id))
        }
      }
      .padding(.horizontal, metrics.inset)
    }
#if os(tvOS)
    // Full-width focus section so Up from any episode finds the tab strip; defaultFocus
    // parks on the selected season rather than a programmatic bridge.
    .frame(maxWidth: .infinity)
    .focusSection()
    .defaultFocus($focusedSeasonID, selectedSeasonID ?? seasons.first?.id)
#endif
  }

  // MARK: - Episode rail

  private var episodeRail: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      // Same lazy landscape strip as `MediaPosterShelf`: width from `ShelfMetrics`,
      // vertical room for the focus lift, nothing bespoke about the cards.
      LazyHStack(alignment: .top, spacing: metrics.gutter) {
        ForEach(entries) { entry in
          let isFocusedEpisode = focusedEpisodeID == entry.id
          railCard(for: entry)
            .frame(width: cardWidth)
#if os(tvOS)
            .focused($focusedEpisodeID, equals: entry.id)
#else
            .buttonStyle(MediaCardButtonStyle())
#endif
            .zIndex(isFocusedEpisode ? 1 : 0)
            .id(Self.episodeAnchor(entry.id))
        }
      }
      .padding(.vertical, Metrics.landscapeFocusPadding)
    }
    // Content margins, not padding: `scrollTo(anchor: .leading)` would otherwise park
    // the first episode of a season under the page inset instead of beside it.
    .contentMargins(.horizontal, metrics.inset, for: .scrollContent)
#if os(tvOS)
    // Focus scale needs to paint past the clip; on Mac it lets the first card
    // draw under the translucent sidebar.
    .buttonStyle(.borderless)
    .scrollClipDisabled()
    .focusSection()
    .defaultFocus($focusedEpisodeID, firstEpisodeInSelectedSeason)
#endif
  }

  @ViewBuilder
  private func railCard(for entry: RailEntry) -> some View {
    switch entry {
    case .playable(let season, let episode, let schedule) where schedule?.isUpcoming != true:
      PlayerLink(route: linkProvider.player(for: filled(episode, in: season)),
                 item: filled(episode, in: season),
                 mode: .media) {
        MediaCardView(card: Self.card(for: episode, in: season, schedule: schedule),
                      caption: .always)
      }
      .modifier(MediaCardContextMenuModifier(
        entries: contextEntries(for: episode, season: season)
      ))

    case .playable(let season, let episode, let schedule):
      // Announced but not out yet: the same card, inert and dimmed.
      MediaCardView(card: Self.card(for: episode,
                                    in: season,
                                    schedule: schedule,
                                    primaryAction: .openDetail),
                    caption: .always)
        .opacity(0.55)

    case .unavailable(_, let schedule):
      MediaCardView(card: MediaCard(unavailableEpisodeID: entry.id,
                                    number: schedule.episodeNumber,
                                    title: schedule.name,
                                    episodeLabel: Self.episodeLabel(number: schedule.episodeNumber),
                                    dateLabel: schedule.airDate.map(Self.airDateLabel),
                                    stillURL: schedule.still?.absoluteString),
                    caption: .always)
        .opacity(0.55)

    case .missingSeasons(let from, let to, let episodes, let firstAir, let lastAir):
      MissingSeasonsCard(from: from,
                         to: to,
                         episodes: episodes,
                         firstAir: firstAir,
                         lastAir: lastAir,
                         stillHeight: stillHeight)

    case .upcomingSeason(let number, let date, let poster):
      UpcomingSeasonCard(number: number, date: date, poster: poster, stillHeight: stillHeight)
    }
  }

  /// Selects a season and scrolls the episode rail to its first episode. Used by tab
  /// focus, tab activation, and the initial jump to the first unfinished episode.
  /// - Parameter entryEpisodeID: the specific episode to land the rail on. Defaults to
  ///   that season's first episode — correct for a manual tab click/switch. Only the
  ///   initial resume jump (`scrollToFirstUnseen`) passes a specific target here.
  private func selectSeason(_ seasonID: Int, entryEpisodeID: Int? = nil, proxy: ScrollViewProxy, animated: Bool) {
    guard let season = seasons.first(where: { $0.id == seasonID }),
          let first = entries.first(where: { $0.season?.id == seasonID }) else { return }
    let target = entryEpisodeID.flatMap { id in entries.first(where: { $0.id == id }) } ?? first
    selectedSeasonID = seasonID
    seasonEntryEpisodeID = target.id
    onSeasonVisible?(season.number)
    let anchor = Self.episodeAnchor(target.id)
    isScrollingFromTab = true
    if animated {
      withAnimation(.easeOut(duration: 0.2)) {
        proxy.scrollTo(anchor, anchor: .leading)
      }
    } else {
      proxy.scrollTo(anchor, anchor: .leading)
    }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(250))
      isScrollingFromTab = false
    }
  }

  private func scrollToFirstUnseen(proxy: ScrollViewProxy) async {
    guard !didScrollToUnseen, let target = firstUnseen, let season = target.season else { return }
    didScrollToUnseen = true
    try? await Task.sleep(for: .milliseconds(120))
    guard !Task.isCancelled else { return }
    // The specific resume episode, not just its season — see `seasonEntryEpisodeID`.
    selectSeason(season.id, entryEpisodeID: target.id, proxy: proxy, animated: false)
  }

  private func contextEntries(for episode: Episode, season: Season) -> [MediaCardContextEntry] {
    let card = Self.card(for: episode, in: season, schedule: nil)
    let containing = cardMenu.containingFolders(for: card)
    let folders = cardMenu.folders.map {
      MediaCardContextMenus.BookmarkFolderOption(
        id: $0.id,
        title: $0.title,
        isContaining: containing.contains($0.id)
      )
    }
    return MediaCardContextMenus.entries(
      for: card,
      surface: .shelf,
      bookmarkFolders: folders,
      onPlay: nil,
      onGoToTitle: nil,
      onToggleWatchlist: { cardMenu.toggleWatchlist(card) },
      onToggleBookmarkFolder: { folderID in
        guard let folder = cardMenu.folders.first(where: { $0.id == folderID }) else { return }
        cardMenu.toggleBookmark(itemID: card.itemID,
                                folder: folder,
                                serverHint: Set(card.bookmarkFolderIDs))
      },
      onCreateBookmarkFolder: { cardMenu.promptNewFolder(for: card.itemID) },
      onToggleWatched: { onToggleWatched?(episode, season) },
      onHide: { onHide?(episode, season) },
      onOpenImageURL: { openURL($0) }
    )
  }

  /// Episodes arrive without their season/media context, which playback needs.
  private func filled(_ episode: Episode, in season: Season) -> Episode {
    episode.seasonNumber = season.number
    episode.mediaId = season.mediaId
    episode.seriesTitle = seriesTitle
    return episode
  }

  /// The rail's card — the same landscape `MediaCard` History and Continue Watching
  /// draw, captioned "EPISODE 9 · 5 Mar" where the poster shelves caption "S2, E5".
  private static func card(for episode: Episode,
                           in season: Season,
                           schedule: EpisodeSchedule?,
                           primaryAction: MediaCardPrimaryAction = .play) -> MediaCard {
    MediaCard(episode: episode,
              in: season,
              title: displayTitle(episode: episode, schedule: schedule),
              episodeLabel: episodeLabel(number: episode.number),
              dateLabel: schedule?.airDate.map(airDateLabel),
              stillURL: stillURL(episode: episode, schedule: schedule),
              primaryAction: primaryAction)
  }

  private static func displayTitle(episode: Episode, schedule: EpisodeSchedule?) -> String {
    let kino = episode.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !kino.isEmpty { return kino }
    return schedule?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private static func stillURL(episode: Episode, schedule: EpisodeSchedule?) -> String? {
    if !episode.thumbnail.isEmpty { return episode.thumbnail }
    return schedule?.still?.absoluteString
  }

  private static func episodeLabel(number: Int) -> String {
    "\("Episode".localized) \(number)"
  }

  /// Inside a week either way the date is relative — "in 3 days", "7 days ago", and
  /// "tomorrow" / "yesterday" for the ends. Further out it is an absolute date **with
  /// the year**: a rail spans seasons, so a bare "8 Jul" says nothing about which one.
  static func airDateLabel(_ date: Date) -> String {
    let calendar = Calendar.current
    let days = calendar.dateComponents([.day],
                                       from: calendar.startOfDay(for: Date()),
                                       to: calendar.startOfDay(for: date)).day ?? 0
    guard abs(days) > 7 else {
      let formatter = RelativeDateTimeFormatter()
      formatter.dateTimeStyle = .named
      formatter.unitsStyle = .full
      return formatter.localizedString(from: DateComponents(day: days))
    }
    return airDateFormatter.string(from: date)
  }

  private static let airDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
    return formatter
  }()

  private static func seasonTitle(_ season: Season) -> String {
    if season.title.isEmpty {
      return "\("Season".localized) \(season.number)"
    }
    return season.title
  }

  private static func episodeAnchor(_ id: Int) -> String { "episode-\(id)" }

#if os(tvOS)
  static let tabSpacing: CGFloat = 2
  static let tabFont: Font = .system(size: 36, weight: .bold)
  /// Width to lay out with until the rail has measured itself.
  static let referenceWidth: CGFloat = 1920
#elseif os(macOS)
  static let tabSpacing: CGFloat = 8
  static let tabFont: Font = .system(size: 16, weight: .semibold)
  static let referenceWidth: CGFloat = 1100
#else
  static let tabSpacing: CGFloat = 8
  static let tabFont: Font = .system(size: 16, weight: .semibold)
  static let referenceWidth: CGFloat = 390
#endif
}

/// A season tab: filled when selected, outlined otherwise, and lifting on focus.
private struct SeasonTabButtonStyle: ButtonStyle {
  let isSelected: Bool

  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Tab(configuration: configuration, isSelected: isSelected)
  }

  private struct Tab: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
            .foregroundStyle(
                isSelected || isFocused ? Color.primary : Color.secondary
            )
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isFocused ? Color.secondary.opacity(0.4) : Color.clear)
          )

//        .scaleEffect(isFocused ? 1.06 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
  }
}

// MARK: - Trailing cards (missing / upcoming seasons)

/// One dark slot for whole seasons between kino.pub's last and the next announced
/// one — "Сезоны 6–13 · 2013–2021 · 120 эп." — instead of a strip of dead tabs.
private struct MissingSeasonsCard: View {
  let from: Int
  let to: Int
  let episodes: Int?
  let firstAir: Date?
  let lastAir: Date?
  /// Artwork height of the neighbouring episode cards, so the slot lines up with them.
  let stillHeight: CGFloat

  private var yearsText: String? {
    guard let firstAir else { return nil }
    let firstYear = Calendar.current.component(.year, from: firstAir)
    let lastYear = lastAir.map { Calendar.current.component(.year, from: $0) }
    return lastYear != nil && lastYear != firstYear ? "\(firstYear)–\(lastYear!)" : "\(firstYear)"
  }

  private var subtitle: String? {
    var parts: [String] = []
    if let yearsText { parts.append(yearsText) }
    if let episodes { parts.append("\(episodes) \("MediaItem_EpisodesShort".localized)") }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  var body: some View {
    VStack(spacing: 10) {
      Text(String(format: "MediaItem_SeasonsRange".localized, from, to))
        .font(TypeScale.cardTitle)
        .foregroundStyle(Color.KinoPub.text)
        .multilineTextAlignment(.center)

      if let subtitle {
        Text(subtitle)
          .font(TypeScale.cardMeta)
          .foregroundStyle(Color.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 24)
    .frame(maxWidth: .infinity)
    .frame(height: stillHeight)
    .background(
      RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
        .fill(Color.secondary.opacity(0.18))
    )
  }
}

/// The announced season ahead of everything kino.pub has: poster, "Сезон 19",
/// premiere date and countdown. Inert — there is nothing to play yet.
private struct UpcomingSeasonCard: View {
  let number: Int
  let date: Date
  let poster: URL?
  /// Artwork height of the neighbouring episode cards, so the poster lines up with them.
  let stillHeight: CGFloat

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
    return formatter
  }()

  private var countdown: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  var body: some View {
    VStack(alignment: .center, spacing: 6) {
      AsyncImage(url: poster) { phase in
        Group {
          if let image = phase.image {
            image.resizable().aspectRatio(contentMode: .fill)
          } else {
            Color.KinoPub.placeholder
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: stillHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
      }

      Text(String(format: "MediaItem_SeasonSingle".localized, number))
        .font(TypeScale.cardTitle)
        .foregroundStyle(Color.KinoPub.text)
        .lineLimit(1)

      Text(String(format: "MediaItem_PremiereOn".localized, Self.dateFormatter.string(from: date)))
        .font(TypeScale.cardMeta)
        .foregroundStyle(Color.secondary)
        .lineLimit(2)
        .multilineTextAlignment(.center)

      Text(countdown)
        .font(TypeScale.cardMeta)
        .foregroundStyle(Color.secondary.opacity(0.7))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .top)
  }
}
