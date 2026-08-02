//
//  HistoryView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

/// Viewing history as a single landscape row. Used as the Recently Watched tab
/// content and still pushed from Continue Watching's "Browse History" menu.
/// Reads through `ContentStore`, so a warm cache paints instantly and a failed
/// refresh keeps the last known list instead of blanking the screen.
struct HistoryView: View {
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext

  @State private var cards: [MediaCard] = []
  @State private var isLoaded = false
  @State private var loadFailed = false
  @State private var loadError: Error?

  var body: some View {
    Group {
      if cards.isEmpty && !isLoaded {
        LoadingIndicatorView()
      } else if cards.isEmpty && loadFailed {
        UnavailableView(title: "Couldn't Load",
                        systemImage: "wifi.exclamationmark",
                        message: loadError?.userFacingMessage ?? "Check your connection and try again.".localized,
                        retryTitle: "Try Again",
                        onRetry: {
          Task { await load(force: true) }
        })
      } else if cards.isEmpty {
        UnavailableView(title: "No History", systemImage: "clock")
      } else {
        MediaRowsView(
          rows: [MediaRow(id: "history", title: "Recently Watched".localized, cards: cards)],
          navigationLinkProvider: { card in MainRoutes.detailsById(card.itemID) }
        )
      }
    }
    .platformNavigationTitle("Recently Watched")
    .background(Color.KinoPub.background)
    .task { await load() }
    .handleError(state: $errorHandler.state)
  }

  private func load(force: Bool = false) async {
    let store = appContext.contentStore
    cards = store.cards(.history)
    isLoaded = !cards.isEmpty
    loadFailed = false
    loadError = nil

    let willFetch = force || store.isStale(.history)
    let service = appContext.contentService
    let fetch: @Sendable () async throws -> [MediaCard] = {
      let history = try await service.fetchHistory().history
      return Self.cards(from: history)
    }
    if force {
      await store.refresh(.history, fetch: fetch)
    } else {
      await store.refreshIfStale(.history, fetch: fetch)
    }

    cards = store.cards(.history)
    isLoaded = true
    loadFailed = cards.isEmpty && store.lastError(.history) != nil
    loadError = cards.isEmpty ? store.lastError(.history) : nil
    if willFetch, !cards.isEmpty, let error = store.lastError(.history) {
      // Content stayed on screen; just say the refresh didn't land.
      errorHandler.setError(error)
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
      let isSeries = entry.isEpisode || (entry.item.type?.contains("serial") ?? false)
      var label: [String] = []
      if entry.isEpisode, let season = entry.media?.snumber, let episode = entry.media?.number {
        label.append("S\(season), E\(episode)")
      }
      if let duration = entry.media?.duration, duration >= 60 {
        label.append(Duration.hoursMinutes(seconds: duration))
      }
      result.append(MediaCard(
        id: entry.item.id,
        posterURL: posters?.medium ?? wide,
        title: entry.item.title?.components(separatedBy: " / ").first
          ?? entry.item.title
          ?? "",
        progress: entry.progress,
        landscapeImageURL: wide,
        overlayLabel: label.isEmpty ? nil : label.joined(separator: " · "),
        itemID: entry.item.id,
        video: entry.media?.number,
        season: entry.isEpisode ? entry.media?.snumber : nil,
        mediaID: entry.media?.id,
        isSeries: isSeries,
        isInHistory: true
      ))
    }
    return result
  }
}
