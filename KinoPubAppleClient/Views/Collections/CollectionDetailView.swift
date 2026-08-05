//
//  CollectionDetailView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// The grid behind one collection shelf's title / "+N more" — every item the
/// collection has, no pagination (the endpoint returns them all at once).
struct CollectionDetailView: View {
  @EnvironmentObject var navigationState: NavigationState
  @Environment(ErrorHandler.self) var errorHandler
  @Environment(\.openURL) private var openURL
  @StateObject private var model: CollectionDetailModel
  @StateObject private var cardMenu = MediaCardMenuCoordinator()

  init(model: @autoclosure @escaping () -> CollectionDetailModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    @Bindable var errorHandler = errorHandler
    content
      .platformNavigationTitle(model.title)
      .background(Color.KinoPub.background)
      .task {
        cardMenu.bind(errorHandler: errorHandler)
        await model.fetch()
      }
      .task { await cardMenu.refreshFolders() }
      .mediaCardNewFolderAlert(cardMenu)
      .handleError(state: $errorHandler.state)
  }

  @ViewBuilder
  private var content: some View {
    if model.items.isEmpty && model.isLoading {
      LoadingIndicatorView()
    } else if model.items.isEmpty && model.loadFailed {
      UnavailableView(title: "Couldn't Load",
                      systemImage: "wifi.exclamationmark",
                      message: model.loadError?.userFacingMessage ?? "Check your connection and try again.".localized,
                      retryTitle: "Try Again",
                      onRetry: {
        Task { await model.fetch() }
      })
    } else if model.items.isEmpty {
      UnavailableView(title: "No Results", systemImage: "rectangle.stack")
    } else {
      ContentItemsListView(
        items: $model.items,
        onLoadMoreContent: { _ in },
        navigationLinkProvider: { item in Route.details(item) },
        contextMenuProvider: { item in
          MediaCardContextMenus.entries(
            for: item,
            menu: cardMenu,
            pushRoute: { navigationState.push($0) },
            openURL: { openURL($0) }
          )
        }
      )
    }
  }

  static func make(collection: Collection,
                   context: AppContextProtocol,
                   errorHandler: ErrorHandler) -> CollectionDetailView {
    CollectionDetailView(model: CollectionDetailModel(collection: collection,
                                                       collectionsService: context.collectionsService,
                                                       errorHandler: errorHandler))
  }
}

struct CollectionDetailView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      CollectionDetailView(model: CollectionDetailModel(collection: .mock(id: 1, title: "Mock Collection"),
                                                         collectionsService: CollectionsServiceMock(),
                                                         errorHandler: ErrorHandler()))
    }
  }
}
