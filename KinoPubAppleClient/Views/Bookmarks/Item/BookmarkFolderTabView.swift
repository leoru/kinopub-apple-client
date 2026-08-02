//
//  BookmarkFolderTabView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// One bookmark folder as a sidebar tab — own stack so folder switches stay isolated.
struct BookmarkFolderTabView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext

  let bookmark: Bookmark
  @State private var path: [BookmarksRoutes] = []

  var body: some View {
    NavigationStack(path: $path) {
      BookmarkView(model: BookmarkModel(bookmark: bookmark,
                                        itemsService: appContext.contentService,
                                        errorHandler: errorHandler))
        .navigationDestination(for: Route.self) { route in
          RouteDestination(route: route, linkProvider: AppRoutesLinkProvider())
        }
    }
    .navigationStackActive(for: .bookmark(bookmark.id), selected: navigationState.selectedTab)
    .id(bookmark.id)
  }

}
