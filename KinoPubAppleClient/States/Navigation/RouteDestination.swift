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
  @Environment(ErrorHandler.self) private var errorHandler
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
    case .collections:
      CollectionsView.make(context: appContext,
                           authState: authState,
                           errorHandler: errorHandler)
    case .collection(let collection):
      CollectionDetailView.make(collection: collection,
                                context: appContext,
                                errorHandler: errorHandler)
    case .player(let item):
#if os(macOS)
      MacPlayerRouteGuard(item: item, mode: .media)
#else
      PlayerView(manager: PlaybackSession.shared.play(
        item: item,
        mode: .media,
        downloadedFilesDatabase: appContext.downloadedFilesDatabase,
        actionsService: appContext.actionsService
      ))
#endif
    case .trailerPlayer(let item):
#if os(macOS)
      MacPlayerRouteGuard(item: item, mode: .trailer)
#else
      PlayerView(manager: PlaybackSession.shared.play(
        item: item,
        mode: .trailer,
        downloadedFilesDatabase: appContext.downloadedFilesDatabase,
        actionsService: appContext.actionsService
      ))
#endif
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

#if os(macOS)
/// Safety net, not the fix: the player is never supposed to reach the main stack on
/// macOS — every Play entry point either uses `PlayerLink` or routes through
/// `NavigationState.push`, both of which open the dedicated window directly (see
/// `ROADMAP.md`, "macOS presentation"). If a
/// `.player` / `.trailerPlayer` route still lands here, open the window and pop this
/// destination instead of showing the player inline next to the sidebar.
private struct MacPlayerRouteGuard: View {
  let item: any PlayableItem
  let mode: WatchMode

  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Color.clear
      .onAppear {
        assertionFailure("'.player'/'.trailerPlayer' reached the main stack on macOS — route through PlayerLink instead")
        PlaybackWindowState.shared.request = PlaybackWindowState.Request(item: item, mode: mode)
        openWindow(id: PlaybackWindowState.windowID)
        dismiss()
      }
  }
}
#endif

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
