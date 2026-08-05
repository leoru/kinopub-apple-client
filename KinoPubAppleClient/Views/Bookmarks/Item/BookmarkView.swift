//
//  BookmarkView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend

struct BookmarkView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.openURL) private var openURL

  @StateObject private var model: BookmarkModel
  @StateObject private var cardMenu = MediaCardMenuCoordinator()
  @Environment(\.appContext) var appContext

  init(model: @autoclosure @escaping () -> BookmarkModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    VStack {
      listView
    }
    .platformNavigationTitle(model.bookmark.title)
    .background(Color.KinoPub.background)
    .task {
      cardMenu.bind(errorHandler: errorHandler)
      await model.fetchItems()
    }
    .task { await cardMenu.refreshFolders() }
    .mediaCardNewFolderAlert(cardMenu)
    .handleError(state: $errorHandler.state)
  }

  @ViewBuilder
  var listView: some View {
    if model.items.isEmpty && model.isLoading {
      LoadingIndicatorView()
    } else {
      grid
    }
  }

  private var grid: some View {
    ContentItemsListView(
      items: $model.items,
      onLoadMoreContent: { item in
        model.loadMoreContent(after: item)
      },
      navigationLinkProvider: { item in
        BookmarksRoutesLinkProvider().link(for: item)
      },
      contextMenuProvider: { item in
        MediaCardContextMenus.entries(
          for: item,
          menu: cardMenu,
          pushRoute: { navigationState.push($0) },
          openURL: { openURL($0) }
        )
      },
      paginationError: model.paginationFailed,
      onRetryPagination: {
        model.retryPagination()
      }
    )
  }
}
