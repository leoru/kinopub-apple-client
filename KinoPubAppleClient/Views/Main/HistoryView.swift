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

/// Viewing history as a vertical poster-column grid. Landscape tiles by default
/// (episode still when the payload has one); macOS View menu can switch to posters.
struct HistoryView: View {
  @Environment(ErrorHandler.self) var errorHandler
  @EnvironmentObject var navigationState: NavigationState
  @Environment(\.appContext) var appContext
  @Environment(\.openURL) private var openURL
  @StateObject private var cardMenu = MediaCardMenuCoordinator()

  @AppStorage(HistoryCardLayout.storageKey) private var layoutRaw: String = HistoryCardLayout.landscape.rawValue

  @State private var cards: [MediaCard] = []
  @State private var pagination: Pagination?
  @State private var isLoaded = false
  @State private var isFetching = false
  @State private var loadFailed = false
  @State private var loadError: Error?
  @State private var paginationFailed = false

  private var layout: HistoryCardLayout {
    HistoryCardLayout(rawValue: layoutRaw) ?? .landscape
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
          paginationError: paginationFailed,
          onRetryPagination: { retryPagination() }
        )
      }
    }
    .platformNavigationTitle("Recently Watched")
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

    do {
      let page = isFirstPage ? nil : pagination.map { $0.current + 1 }
      let data = try await appContext.contentService.fetchHistory(page: page)
      let newCards = Self.cards(from: data.history)
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

  nonisolated static func cards(from history: [HistoryEntry]) -> [MediaCard] {
    // One card per title, newest play first — matches Continue Watching's collapse.
    var seen = Set<Int>()
    var result: [MediaCard] = []
    for entry in history.sorted(by: { ($0.lastSeen ?? 0) > ($1.lastSeen ?? 0) }) {
      guard seen.insert(entry.item.id).inserted else { continue }
      let posters = entry.item.posters
      let wide = posters?.wideURL ?? posters?.big ?? posters?.medium ?? ""
      let episodeStill = entry.media?.thumbnail.flatMap { $0.isEmpty ? nil : $0 }
      let landscape = episodeStill ?? wide
      let isSeries = entry.isEpisode || (entry.item.type?.contains("serial") ?? false)
      var label: [String] = []
      if entry.isEpisode, let season = entry.media?.snumber, let episode = entry.media?.number {
        label.append("S\(season), E\(episode)")
      }
      let durationSeconds = entry.media?.duration.flatMap { $0 >= 60 ? $0 : nil }
      result.append(MediaCard(
        id: entry.item.id,
        posterURL: posters?.medium ?? wide,
        title: entry.item.title?.components(separatedBy: " / ").first
          ?? entry.item.title
          ?? "",
        subtitle: entry.item.title?.components(separatedBy: " / ").last,
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
      ))
    }
    return result
  }
}
