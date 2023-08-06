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
  @StateObject private var model: BookmarkModel
  @Environment(\.appContext) var appContext

  init(model: @autoclosure @escaping () -> BookmarkModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    VStack {
      listView
    }
    .navigationTitle(model.bookmark.title)
    .background(Color.KinoPub.background)
    .task {
      await model.fetchItems()
    }
  }

  var listView: some View {
    GeometryReader { geometryProxy in
      ContentItemsListView(width: geometryProxy.size.width, items: $model.items, onLoadMoreContent: { item in
        
      }, onRefresh: {
        await model.refresh()
      }, navigationLinkProvider: { item in
        BookmarksRoutesLinkProvider().link(for: item)
      })
    }
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
