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
  
  @StateObject private var model: BookmarkModel
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
      await model.fetchItems()
    }
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
    ContentItemsListView(items: $model.items, onLoadMoreContent: { item in

    }, navigationLinkProvider: { item in
      BookmarksRoutesLinkProvider().link(for: item)
    })
  }
}
//
//struct BookmarkView_Previews: PreviewProvider {
//  @StateObject static var navState = NavigationState()
//
//  static var previews: some View {
//    MainView(catalog: MediaCatalog(itemsService: VideoContentServiceMock(), authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock())))
//      .environmentObject(navState)
//  }
//}
//
