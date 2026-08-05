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
  @StateObject private var cardMenu = MediaCardMenuCoordinator()
  @State private var selectedSeasonID: Int?
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

  /// First unfinished playable episode walking seasons in order, else the very first rail item.
  private var firstUnseen: RailEntry? {
    entries.first {
      if case .playable(_, let episode, _) = $0 { return episode.watched == 0 }
      return false
    } ?? entries.first
  }

  /// Episode to land on when Down crosses from the season tabs into the rail.
  private var firstEpisodeInSelectedSeason: Int? {
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
      .padding(.horizontal, Self.horizontalInset)
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
      LazyHStack(alignment: .top, spacing: Self.cardSpacing) {
        ForEach(entries) { entry in
          let isFocusedEpisode = focusedEpisodeID == entry.id
          railCard(for: entry)
#if os(tvOS)
            .focused($focusedEpisodeID, equals: entry.id)
#endif
            .zIndex(isFocusedEpisode ? 1 : 0)
            .id(Self.episodeAnchor(entry.id))
        }
      }
      .padding(.vertical, Self.focusPadding)
    }
    .contentMargins(.horizontal, Self.horizontalInset, for: .scrollContent)
#if os(tvOS)
    // Focus scale needs to paint past the clip; on Mac it lets the first card
    // draw under the translucent sidebar.
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
        EpisodeRailCard(
          title: Self.displayTitle(episode: episode, schedule: schedule),
          number: episode.number,
          stillURL: Self.stillURL(episode: episode, schedule: schedule),
          schedule: schedule,
          progress: Self.progress(for: episode)
        )
      }
      .buttonStyle(EpisodeCardButtonStyle())
      .modifier(MediaCardContextMenuModifier(
        entries: contextEntries(for: episode, season: season)
      ))

    case .playable(_, let episode, let schedule):
      Button(action: {}) {
        EpisodeRailCard(
          title: Self.displayTitle(episode: episode, schedule: schedule),
          number: episode.number,
          stillURL: Self.stillURL(episode: episode, schedule: schedule),
          schedule: schedule,
          progress: nil
        )
      }
      .buttonStyle(EpisodeCardButtonStyle())
      .disabled(true)
      .opacity(0.55)

    case .unavailable(_, let schedule):
      Button(action: {}) {
        EpisodeRailCard(
          title: schedule.name ?? "",
          number: schedule.episodeNumber,
          stillURL: schedule.still,
          schedule: schedule,
          progress: nil
        )
      }
      .buttonStyle(EpisodeCardButtonStyle())
      .disabled(true)
      .opacity(0.55)

    case .missingSeasons(let from, let to, let episodes, let firstAir, let lastAir):
      MissingSeasonsCard(from: from, to: to, episodes: episodes, firstAir: firstAir, lastAir: lastAir)

    case .upcomingSeason(let number, let date, let poster):
      UpcomingSeasonCard(number: number, date: date, poster: poster)
    }
  }

  /// Selects a season and scrolls the episode rail to its first episode. Used by tab
  /// focus, tab activation, and the initial jump to the first unfinished episode.
  private func selectSeason(_ seasonID: Int, proxy: ScrollViewProxy, animated: Bool) {
    guard let season = seasons.first(where: { $0.id == seasonID }),
          let first = entries.first(where: { $0.season?.id == seasonID }) else { return }
    selectedSeasonID = seasonID
    onSeasonVisible?(season.number)
    let anchor = Self.episodeAnchor(first.id)
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
    selectSeason(season.id, proxy: proxy, animated: false)
  }

  private func contextEntries(for episode: Episode, season: Season) -> [MediaCardContextEntry] {
    let card = Self.contextCard(for: episode, in: season)
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

  private static func displayTitle(episode: Episode, schedule: EpisodeSchedule?) -> String {
    let kino = episode.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !kino.isEmpty { return kino }
    return schedule?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private static func stillURL(episode: Episode, schedule: EpisodeSchedule?) -> URL? {
    if !episode.thumbnail.isEmpty, let url = URL(string: episode.thumbnail) { return url }
    return schedule?.still
  }

  private static func progress(for episode: Episode) -> Double? {
    guard episode.watched == 0, episode.duration > 0, episode.watching.time > 0 else { return nil }
    return min(Double(episode.watching.time) / Double(episode.duration), 1.0)
  }

  private static func contextCard(for episode: Episode, in season: Season) -> MediaCard {
    MediaCard(id: episode.id,
              posterURL: episode.thumbnail,
              title: episode.fixedTitle,
              progress: progress(for: episode),
              landscapeImageURL: episode.thumbnail,
              itemID: season.mediaId ?? episode.mediaId,
              video: episode.number,
              season: season.number,
              mediaID: episode.id,
              isWatched: episode.watched > 0,
              isSeries: true)
  }

  private static func seasonTitle(_ season: Season) -> String {
    if season.title.isEmpty {
      return "\("Season".localized) \(season.number)"
    }
    return season.title
  }

  private static func episodeAnchor(_ id: Int) -> String { "episode-\(id)" }

#if os(tvOS)
  static let horizontalInset: CGFloat = 80
  static let cardSpacing: CGFloat = 36
  static let tabSpacing: CGFloat = 2
  static let focusPadding: CGFloat = 32
  static let tabFont: Font = .system(size: 36, weight: .bold)
#else
  static let horizontalInset: CGFloat = 20
  static let cardSpacing: CGFloat = 16
  static let tabSpacing: CGFloat = 8
  static let focusPadding: CGFloat = 6
  static let tabFont: Font = .system(size: 16, weight: .semibold)
#endif
}

// MARK: - Episode card

/// Fixed 16:9 still + permanent "EPISODE 9" label over a up-to-three-line title.
///
/// Ideally these would be `.fit` with every card sharing the height of the first
/// loaded still (frame == image, no crop, no letterbox). Until that uniform-height
/// pass exists, every card uses the same frame and `.fill`s — crop over broken layout.
///
/// Focus plate hugs the still + real caption (no empty 3-line slack inside the wash).
/// A hidden scaffold still reserves the full caption height in the rail so neighbours
/// don't reflow the section — plate and scale only wrap the content that exists.
private struct EpisodeRailCard: View {

  let title: String
  let number: Int
  let stillURL: URL?
  var schedule: EpisodeSchedule? = nil
  var progress: Double? = nil
  @Environment(\.isFocused) private var isFocused

  private var episodeNumberLabel: String {
    if let airDate = schedule?.airDate {
      return "\("Episode".localized) \(number) · \(Self.airDateFormatter.string(from: airDate))"
    }
    return "\("Episode".localized) \(number)"
  }

  private var episodeTitle: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static let airDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "d MMM"
    f.locale = .current
    return f
  }()

  var body: some View {
    ZStack(alignment: .topLeading) {
      // Invisible slot: still + max caption, keeps every card the same height in the rail.
      VStack(alignment: .leading, spacing: 2) {
        Color.clear
          .frame(width: Self.cardWidth, height: Self.stillHeight)
        captionReserve
          .padding(.horizontal, Self.captionPadding)
          .padding(.top, Self.captionSpacing)
          .padding(.bottom, Self.captionPadding)
      }
      .hidden()
      .accessibilityHidden(true)

      // Visible card: plate hugs this stack only.
      VStack(alignment: .leading, spacing: 2) {
        still
        caption
          .padding(.horizontal, Self.captionPadding)
          .padding(.top, Self.captionSpacing)
          .padding(.bottom, Self.captionPadding)
      }
      .background(
        RoundedRectangle(cornerRadius: Self.plateRadius, style: .continuous)
          .fill(isFocused ? Color.secondary.opacity(0.35) : Color.clear)
      )
      .scaleEffect(isFocused ? 1.05 : 1.0)
      .animation(.easeOut(duration: 0.2), value: isFocused)
    }
    .frame(width: Self.cardWidth, alignment: .topLeading)
  }

  /// Same structure/fonts/line limits as a full caption, for the rail slot only.
  private var captionReserve: some View {
    VStack(alignment: .center, spacing: 6) {
      Text(" ")
        .font(Self.titleFont)
        .lineLimit(1)
        .multilineTextAlignment(.center)
      Text("EPISODE 99")
        .font(Self.numberFont)
        .textCase(.uppercase)
        .lineLimit(1)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }

  @ViewBuilder
  private var caption: some View {
    VStack(alignment: .center, spacing: 6) {
      if !episodeTitle.isEmpty {
        MarqueeText(
          episodeTitle,
          font: Self.titleFont,
          alignment: .center,
          style: .title
        )

        Text(episodeNumberLabel)
          .font(Self.numberFont)
          .foregroundStyle(Color.secondary)
          .textCase(.uppercase)
          .lineLimit(1)
          .multilineTextAlignment(.center)
      } else {
        MarqueeText(
          episodeNumberLabel,
          font: Self.titleFont,
          alignment: .center,
          style: .title
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }

  private var still: some View {
    AsyncImage(url: stillURL,
               transaction: Transaction(animation: .easeIn(duration: 0.25))) { phase in
      ZStack(alignment: .bottom) {
        Group {
          if let image = phase.image {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .transition(.opacity)
          } else {
            Color.KinoPub.placeholder
          }
        }
        .frame(width: Self.cardWidth, height: Self.stillHeight)
        .clipped()
              .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))


        if let progress {
          progressBar(progress)
        }
      }
    }
    .frame(width: Self.cardWidth, height: Self.stillHeight)
//    .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
  }

  private func progressBar(_ progress: Double) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
          Capsule().fill(Color.gray.opacity(0.5))
        Capsule()
          .fill(Color.KinoPub.accent)
          .frame(width: geometry.size.width * progress)
          .shadow(radius: 8)
      }
    }
    .frame(height: 10)
    .padding(.horizontal, 0)
    .padding(.bottom, 0)
  }

  static let titleLineLimit = 3

#if os(tvOS)
  static let cardWidth: CGFloat = 480
  static let stillHeight: CGFloat = 270
  static let cornerRadius: CGFloat = 18
  static let plateRadius: CGFloat = 18
  static let captionSpacing: CGFloat = 12
  static let captionPadding: CGFloat = 20
  static let numberFont: Font = .system(size: 20, weight: .bold)
  static let titleFont: Font = .system(size: 28, weight: .semibold)
#else
  static let cardWidth: CGFloat = 300
  static let stillHeight: CGFloat = 169
  static let cornerRadius: CGFloat = 12
  static let plateRadius: CGFloat = 14
  static let captionSpacing: CGFloat = 8
  static let captionPadding: CGFloat = 8
  static let numberFont: Font = .system(size: 11, weight: .semibold)
  static let titleFont: Font = .system(size: 15, weight: .medium)
#endif
}

/// Press feedback only — focus plate and scale live on `EpisodeRailCard`.
private struct EpisodeCardButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.92 : 1.0)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
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
        .font(EpisodeRailCard.titleFont)
        .foregroundStyle(Color.KinoPub.text)
        .multilineTextAlignment(.center)

      if let subtitle {
        Text(subtitle)
          .font(EpisodeRailCard.numberFont)
          .foregroundStyle(Color.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 24)
    .frame(width: EpisodeRailCard.cardWidth,
           height: EpisodeRailCard.stillHeight + 80)
    .background(
      RoundedRectangle(cornerRadius: EpisodeRailCard.cornerRadius, style: .continuous)
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
        .frame(width: EpisodeRailCard.cardWidth, height: EpisodeRailCard.stillHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: EpisodeRailCard.cornerRadius, style: .continuous))
      }

      Text(String(format: "MediaItem_SeasonSingle".localized, number))
        .font(EpisodeRailCard.titleFont)
        .foregroundStyle(Color.KinoPub.text)
        .lineLimit(1)

      Text(String(format: "MediaItem_PremiereOn".localized, Self.dateFormatter.string(from: date)))
        .font(EpisodeRailCard.numberFont)
        .foregroundStyle(Color.secondary)
        .lineLimit(2)
        .multilineTextAlignment(.center)

      Text(countdown)
        .font(EpisodeRailCard.numberFont)
        .foregroundStyle(Color.secondary.opacity(0.7))
        .lineLimit(1)
    }
    .frame(width: EpisodeRailCard.cardWidth, alignment: .topLeading)
  }
}
