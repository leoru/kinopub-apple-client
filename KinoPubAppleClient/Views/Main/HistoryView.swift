//
//  HistoryView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubBackend
import KinoPubUI
import OSLog
import KinoPubLogging

/// macOS View-menu preference for the History grid. Default is landscape (episode
/// stills when the history payload carries a thumbnail).
enum HistoryCardLayout: String, CaseIterable, Identifiable {
  case landscape
  case posters

  var id: String { rawValue }

  static let storageKey = "historyCardLayout"

  var titleKey: String {
    switch self {
    case .landscape: return "Landscape"
    case .posters: return "Posters"
    }
  }
}

/// Whether the history list collapses repeated plays of one title into a single card.
///
/// **Off by default, on purpose.** History is one row per play, and collapsing it was
/// the shipped behaviour with no way out — someone working through a season saw one
/// card where the API had sent twenty, and no indication that anything had been
/// merged. The default is now what the API actually returned; collapsing is a choice.
enum HistoryGrouping: String, CaseIterable, Identifiable {
  /// One card per history entry, in the order the API sent them.
  case none
  /// One card per title, newest play first.
  case byShow

  var id: String { rawValue }

  static let storageKey = "historyGrouping"

  /// `@AppStorage` is a view-side wrapper; the catalogs that build history cards are
  /// plain models, so both read the same default through here.
  static var current: HistoryGrouping {
    UserDefaults.standard.string(forKey: storageKey).flatMap(HistoryGrouping.init(rawValue:)) ?? .none
  }

  var titleKey: String {
    switch self {
    case .none: return "History_Group_None"
    case .byShow: return "History_Group_ByShow"
    }
  }
}

/// Whether the history list is broken into dated sections, and how coarse they are.
enum HistorySectioning: String, CaseIterable, Identifiable {
  case none
  case day
  case month

  var id: String { rawValue }

  static let storageKey = "historySectioning"

  static var current: HistorySectioning {
    UserDefaults.standard.string(forKey: storageKey).flatMap(HistorySectioning.init(rawValue:)) ?? .month
  }

  var titleKey: String {
    switch self {
    case .none: return "History_Section_None"
    case .day: return "History_Section_Day"
    case .month: return "History_Section_Month"
    }
  }

  /// The bucket an entry falls into, and the heading that bucket gets. Nil means the
  /// entry has no usable timestamp and belongs in no section.
  func bucket(for date: Date?, calendar: Calendar = .current) -> (key: Date, title: String)? {
    guard let date else { return nil }
    switch self {
    case .none:
      return nil
    case .day:
      let start = calendar.startOfDay(for: date)
      return (start, Self.dayTitle(for: start, calendar: calendar))
    case .month:
      let components = calendar.dateComponents([.year, .month], from: date)
      guard let start = calendar.date(from: components) else { return nil }
      return (start, start.formatted(.dateTime.month(.wide).year()))
    }
  }

  /// Cards into headed buckets, preserving the order they arrive in. Anything without
  /// a usable timestamp falls into a trailing bucket rather than being dropped — a
  /// history row we cannot date is still a row the user watched.
  func sections(for cards: [MediaCard]) -> [MediaCardSection] {
    guard self != .none else { return [] }
    var order: [Date] = []
    var grouped: [Date: [MediaCard]] = [:]
    var titles: [Date: String] = [:]
    var undated: [MediaCard] = []

    for card in cards {
      guard let bucket = bucket(for: card.watchedAt) else {
        undated.append(card)
        continue
      }
      if grouped[bucket.key] == nil {
        order.append(bucket.key)
        titles[bucket.key] = bucket.title
      }
      grouped[bucket.key, default: []].append(card)
    }

    var result = order.map { key in
      MediaCardSection(id: "\(key.timeIntervalSince1970)",
                       title: titles[key] ?? "",
                       cards: grouped[key] ?? [])
    }
    if !undated.isEmpty {
      result.append(MediaCardSection(id: "undated", title: "History_Section_Undated".localized, cards: undated))
    }
    return result
  }

  /// "Today" / "Yesterday" beat a date anyone has to parse; older days get the date.
  private static func dayTitle(for day: Date, calendar: Calendar) -> String {
    if calendar.isDateInToday(day) { return "Today".localized }
    if calendar.isDateInYesterday(day) { return "Yesterday".localized }
    return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
  }
}

/// Marks the frontmost scene as showing a list that the View menu's arrangement items
/// apply to.
///
/// Menu items that are always enabled but only sometimes do anything are the thing
/// Apple's own menus avoid: Finder greys out "Clean Up" outside icon view rather than
/// leaving it live and inert. A focused value is how a command learns what is in front
/// of it without the App owning every screen's state.
struct ListArrangementFocusKey: FocusedValueKey {
  typealias Value = Bool
}

extension FocusedValues {
  var showsListArrangement: Bool? {
    get { self[ListArrangementFocusKey.self] }
    set { self[ListArrangementFocusKey.self] = newValue }
  }
}

/// Viewing history as a vertical poster-column grid. Landscape tiles by default
/// (episode still when the payload has one); macOS View menu can switch to posters.
struct HistoryView: View {
  @Environment(ErrorHandler.self) var errorHandler
  @EnvironmentObject var navigationState: NavigationState
  @Environment(\.appContext) var appContext
  @Environment(\.openURL) private var openURL
  @StateObject private var cardMenu = MediaCardMenuCoordinator()

  @AppStorage(HistoryCardLayout.storageKey) private var layoutRaw: String = HistoryCardLayout.landscape.rawValue
  @AppStorage(HistoryGrouping.storageKey) private var groupingRaw: String = HistoryGrouping.none.rawValue
  @AppStorage(HistorySectioning.storageKey) private var sectioningRaw: String = HistorySectioning.month.rawValue

  @State private var cards: [MediaCard] = []
  @State private var pagination: Pagination?
  @State private var isLoaded = false
  @State private var isFetching = false
  @State private var loadFailed = false
  @State private var loadError: Error?
  @State private var paginationFailed = false
  /// A page past the first is in flight. Separate from `isFetching`, which also covers
  /// the first page — that one has its own full-screen loading state.
  @State private var isLoadingMore = false

  /// What the grid footer should say.
  private var paginationState: PaginationState {
    if isLoadingMore { return PaginationState(phase: .loading, loadedCount: displayCards.count) }
    if paginationFailed { return PaginationState(phase: .failed, loadedCount: displayCards.count) }
    guard let pagination, pagination.current >= pagination.total else { return .idle }
    return PaginationState(phase: .complete, loadedCount: displayCards.count)
  }

  private var layout: HistoryCardLayout {
    HistoryCardLayout(rawValue: layoutRaw) ?? .landscape
  }

  private var grouping: HistoryGrouping {
    HistoryGrouping(rawValue: groupingRaw) ?? .none
  }

  private var sectioning: HistorySectioning {
    HistorySectioning(rawValue: sectioningRaw) ?? .none
  }

  private var displayCards: [MediaCard] {
    switch layout {
    case .landscape:
      return cards
    case .posters:
      return cards.map { card in
        MediaCard(
          id: card.id,
          posterURL: card.posterURL,
          title: card.title,
          subtitle: card.subtitle,
          imdbRating: card.imdbRating,
          kinopoiskRating: card.kinopoiskRating,
          progress: card.progress,
          badge: card.badge,
          backdropURL: card.backdropURL,
          overlayLabel: card.overlayLabel,
          itemID: card.itemID,
          video: card.video,
          season: card.season,
          mediaID: card.mediaID,
          isWatched: card.isWatched,
          isSeries: card.isSeries,
          isInHistory: card.isInHistory,
          isInWatchlist: card.isInWatchlist,
          is4K: card.is4K,
          isHDR: card.isHDR,
          isHD: card.isHD,
          is3D: card.is3D,
          hasClosedCaptions: card.hasClosedCaptions,
          year: card.year,
          durationSeconds: card.durationSeconds,
          genreLine: card.genreLine,
          countryLine: card.countryLine,
          isBookmarked: card.isBookmarked,
          bookmarkFolderIDs: card.bookmarkFolderIDs,
          primaryAction: card.primaryAction
        )
      }
    }
  }

  var body: some View {
    @Bindable var errorHandler = errorHandler
    Group {
      if cards.isEmpty && !isLoaded {
        LoadingIndicatorView()
      } else if cards.isEmpty && loadFailed {
        UnavailableView(title: "Couldn't Load",
                        systemImage: "wifi.exclamationmark",
                        message: loadError?.userFacingMessage ?? "Check your connection and try again.".localized,
                        retryTitle: "Try Again",
                        onRetry: {
          Task { await refresh() }
        })
      } else if cards.isEmpty {
        UnavailableView(title: "No History", systemImage: "clock")
      } else {
        MediaCardsListView(
          cards: displayCards,
          onLoadMoreContent: { loadMoreContent(after: $0) },
          navigationLinkProvider: { card in MainRoutes.detailsById(card.itemID) },
          contextMenuProvider: { card in
            MediaCardContextMenus.entries(
              for: card,
              surface: .shelf,
              menu: cardMenu,
              pushRoute: { navigationState.push($0) },
              openURL: { openURL($0) }
            )
          },
          sections: sectioning.sections(for: displayCards),
          pagination: paginationState,
          onRetryPagination: { retryPagination() }
        )
      }
    }
    .platformNavigationTitle("Recently Watched")
    .focusedSceneValue(\.showsListArrangement, true)
#if os(iOS)
    // iPad and iPhone reach the same two options through the toolbar; macOS has them in
    // the View menu, where a Mac user looks for how a list is arranged.
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Menu {
            Picker("Group By", selection: $groupingRaw) {
              ForEach(HistoryGrouping.allCases) { option in
                Text(LocalizedStringKey(option.titleKey)).tag(option.rawValue)
              }
            }
          } label: {
            Label("Group By", systemImage: "rectangle.stack")
          }
          Menu {
            Picker("Group By Date", selection: $sectioningRaw) {
              ForEach(HistorySectioning.allCases) { option in
                Text(LocalizedStringKey(option.titleKey)).tag(option.rawValue)
              }
            }
          } label: {
            Label("Group By Date", systemImage: "calendar")
          }
        } label: {
          Label("View Options", systemImage: "line.3.horizontal.decrease.circle")
        }
      }
    }
#endif
    // Grouping changes what a card *is* — one play or one title — so the list is rebuilt
    // from the API rather than re-arranged in place. Sectioning is pure presentation and
    // needs no refetch.
    .task(id: groupingRaw) {
      guard isLoaded else { return }
      await refresh()
    }
    .background(Color.KinoPub.background)
    .task {
      cardMenu.bind(errorHandler: errorHandler)
      await loadInitial()
    }
    .task { await cardMenu.refreshFolders() }
    .mediaCardNewFolderAlert(cardMenu)
    .handleError(state: $errorHandler.state)
  }

  private func loadInitial() async {
    guard cards.isEmpty else { return }
    await fetchPage(reset: true)
  }

  private func refresh() async {
    errorHandler.reset()
    pagination = nil
    paginationFailed = false
    loadFailed = false
    loadError = nil
    await fetchPage(reset: true)
  }

  private func retryPagination() {
    paginationFailed = false
    Task { await fetchPage(reset: false) }
  }

  private func loadMoreContent(after card: MediaCard) {
    guard let pagination,
          CatalogLoadMore.isThresholdID(card.id, lastID: cards.last?.id),
          pagination.current < pagination.total else {
      return
    }
    Task { await fetchPage(reset: false) }
  }

  private func fetchPage(reset: Bool) async {
    let isFirstPage = reset || pagination == nil
    if !isFirstPage {
      guard !isFetching else { return }
    }
    isFetching = true
    defer { isFetching = false }
    isLoadingMore = !isFirstPage
    defer { isLoadingMore = false }

    do {
      let page = isFirstPage ? nil : pagination.map { $0.current + 1 }
      let data = try await appContext.contentService.fetchHistory(page: page, perPage: LibrarySectionCatalog.historyPerPage)
      let newCards = Self.cards(from: data.history, grouping: grouping)
      if isFirstPage {
        cards = newCards
      } else {
        var seen = Set(cards.map(\.id))
        for card in newCards where seen.insert(card.id).inserted {
          cards.append(card)
        }
      }
      pagination = data.pagination
      isLoaded = true
      loadFailed = false
      loadError = nil
      paginationFailed = false
    } catch {
      if isFirstPage {
        loadFailed = cards.isEmpty
        loadError = error
        Logger.app.error("History first page fetch failed: \(error)")
      } else {
        paginationFailed = true
        Logger.app.debug("History page fetch failed, keeping loaded items: \(error)")
        errorHandler.setError(error)
      }
      isLoaded = true
    }
  }

  /// History rows as cards.
  ///
  /// `grouping` decides whether repeated plays of one title collapse. **Ungrouped is
  /// the default and the honest one** — the API sends one row per play, and the old
  /// unconditional collapse silently hid most of them.
  ///
  /// Ungrouped cards cannot key on `item.id`: the same title appears many times, and
  /// duplicate ids in a `ForEach` are dropped without a word. Each card takes a
  /// synthetic id built from the entry instead, while `itemID` keeps pointing at the
  /// title so navigation and context menus are unaffected.
  nonisolated static func cards(from history: [HistoryEntry],
                                grouping: HistoryGrouping = .none) -> [MediaCard] {
    let ordered = history.sorted { ($0.lastSeen ?? 0) > ($1.lastSeen ?? 0) }
    switch grouping {
    case .byShow:
      var seen = Set<Int>()
      return ordered.compactMap { entry in
        guard seen.insert(entry.item.id).inserted else { return nil }
        return card(for: entry, id: entry.item.id)
      }
    case .none:
      return ordered.map { card(for: $0, id: syntheticID(for: $0)) }
    }
  }


  /// Unique per *play*, and stable across refetches so cards don't lose identity mid
  /// scroll. `media.id` alone repeats when one episode is watched twice, so the
  /// timestamp goes in too.
  private nonisolated static func syntheticID(for entry: HistoryEntry) -> Int {
    var hasher = Hasher()
    hasher.combine(entry.item.id)
    hasher.combine(entry.media?.id)
    hasher.combine(entry.lastSeen)
    // Kept positive: negative ids are the rails' convention for synthetic *placeholder*
    // cards, and these are real, openable entries.
    return abs(hasher.finalize())
  }

  private nonisolated static func card(for entry: HistoryEntry, id: Int) -> MediaCard {
    let posters = entry.item.posters
    let wide = posters?.wideURL ?? posters?.big ?? posters?.medium ?? ""
    let isSeries = entry.isEpisode || (entry.item.type?.contains("serial") ?? false)
    // A film's `media.thumbnail` is a frame grab from somewhere in the middle of it;
    // the wide poster is artwork someone chose. Episodes keep their still, which is
    // the point of an episode still.
    let episodeStill = entry.media?.thumbnail.flatMap { $0.isEmpty ? nil : $0 }
    let landscape = isSeries ? (episodeStill ?? wide) : (wide.isEmpty ? (episodeStill ?? "") : wide)
    var label: [String] = []
    if entry.isEpisode, let season = entry.media?.snumber, let episode = entry.media?.number {
      label.append("S\(season), E\(episode)")
    }
    let durationSeconds = entry.media?.duration.flatMap { $0 >= 60 ? $0 : nil }
    return MediaCard(
      id: id,
      posterURL: posters?.medium ?? wide,
      title: entry.item.title?.components(separatedBy: " / ").first
        ?? entry.item.title
        ?? "",
      subtitle: entry.item.title?.components(separatedBy: " / ").last,
      watchedAt: entry.lastSeenDate,
      progress: entry.progress,
      landscapeImageURL: landscape.isEmpty ? nil : landscape,
      overlayLabel: label.isEmpty ? nil : label.joined(separator: " · "),
      itemID: entry.item.id,
      video: entry.media?.number,
      season: entry.isEpisode ? entry.media?.snumber : nil,
      mediaID: entry.media?.id,
      isSeries: isSeries,
      isInHistory: true,
      durationSeconds: durationSeconds
    )
  }

  /// When it was watched, under the title.
  ///
  /// tvOS keeps the original title: a caption there is read from across a room and
  /// only appears on focus, so a timestamp would crowd out the thing being named.
  private nonisolated static func subtitle(for entry: HistoryEntry) -> String? {
#if os(tvOS)
    return entry.item.title?.components(separatedBy: " / ").last
#else
    guard let date = entry.lastSeenDate else {
      return entry.item.title?.components(separatedBy: " / ").last
    }
    return date.formatted(date: .abbreviated, time: .shortened)
#endif
  }
}
