//
//  HistoryView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

/// Viewing history as a single landscape row. Used as the Recently Watched tab
/// content and still pushed from Continue Watching's "Browse History" menu.
struct HistoryView: View {
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext

  @State private var cards: [MediaCard] = []
  @State private var isLoaded = false

  var body: some View {
    Group {
      if cards.isEmpty && !isLoaded {
        LoadingIndicatorView()
      } else if cards.isEmpty {
        Text("No History".localized)
          .foregroundStyle(Color.KinoPub.subtitle)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        MediaRowsView(
          rows: [MediaRow(id: "history", title: "Recently Watched".localized, cards: cards)],
          navigationLinkProvider: { card in MainRoutes.detailsById(card.itemID) },
          showsFeaturedPreview: false
        )
      }
    }
    .platformNavigationTitle("Recently Watched")
    .background(Color.KinoPub.background)
    .task { await load() }
    .handleError(state: $errorHandler.state)
  }

  private func load() async {
    do {
      let history = try await appContext.contentService.fetchHistory().history
      cards = Self.cards(from: history)
      isLoaded = true
    } catch {
      errorHandler.setError(error)
      isLoaded = true
    }
  }

  private static func cards(from history: [HistoryEntry]) -> [MediaCard] {
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
