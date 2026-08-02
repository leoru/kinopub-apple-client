//
//  RouteDestination.swift
//  KinoPubAppleClient
//
//  Single destination registry for every tab's NavigationStack.
//

import SwiftUI
import KinoPubBackend
import KinoPubKit
import KinoPubUI

struct RouteDestination: View {
  let route: Route
  let linkProvider: NavigationLinkProvider
  /// Namespace for system zoom transitions sourced from cards / banners / cast.
  var transitionNamespace: Namespace.ID?

  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var errorHandler: ErrorHandler
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var navigationState: NavigationState

  var body: some View {
    destination
      .modifier(ZoomDestinationModifier(route: route, namespace: transitionNamespace))
  }

  @ViewBuilder
  private var destination: some View {
    switch route {
    case .details(let item):
      detailsView(for: item.id, knownItem: item)
    case .detailsById(let id):
      detailsView(for: id)
    case .history:
      HistoryView()
    case .bookmark(let bookmark):
      BookmarkView(model: BookmarkModel(bookmark: bookmark,
                                        itemsService: appContext.contentService,
                                        errorHandler: errorHandler))
    case .seasons(let seasons):
      SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: linkProvider))
    case .season(let season):
      SeasonView(model: SeasonModel(season: season, linkProvider: linkProvider))
    case .person(let person):
      PersonItemsView.make(person: person,
                           linkProvider: linkProvider,
                           context: appContext,
                           authState: authState,
                           errorHandler: errorHandler)
    case .player(let item):
      PlayerView(manager: PlaybackSession.shared.play(
        item: item,
        mode: .media,
        downloadedFilesDatabase: appContext.downloadedFilesDatabase,
        actionsService: appContext.actionsService
      ))
    case .trailerPlayer(let item):
      PlayerView(manager: PlaybackSession.shared.play(
        item: item,
        mode: .trailer,
        downloadedFilesDatabase: appContext.downloadedFilesDatabase,
        actionsService: appContext.actionsService
      ))
    }
  }

  private func detailsView(for id: Int, knownItem: MediaItem? = nil) -> some View {
    MediaItemView(model: MediaItemModel(mediaItemId: id,
                                        knownItem: knownItem,
                                        itemsService: appContext.contentService,
                                        downloadManager: appContext.downloadManager,
                                        linkProvider: linkProvider,
                                        errorHandler: errorHandler))
  }
}

/// Applies `navigationTransition(.zoom)` when a matched source namespace is present.
private struct ZoomDestinationModifier: ViewModifier {
  let route: Route
  let namespace: Namespace.ID?

  func body(content: Content) -> some View {
#if os(iOS) || os(tvOS)
    if let namespace, let sourceID = route.zoomSourceID {
      content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
    } else {
      content
    }
#else
    content
#endif
  }
}

extension Route {
  /// Stable zoom source id shared with `matchedTransitionSource` on cards.
  var zoomSourceID: String? {
    switch self {
    case .details(let item):
      return "media-\(item.id)"
    case .detailsById(let id):
      return "media-\(id)"
    case .person(let person):
      return "person-\(person.id)"
    default:
      return nil
    }
  }
}
