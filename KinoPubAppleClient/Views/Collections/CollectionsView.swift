//
//  CollectionsView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Grid of curated kino.pub collection covers. Pushed onto whichever tab's stack
/// opened it (today: Home's "Collections" row) — no `NavigationStack` of its own,
/// same as `PersonItemsView`.
struct CollectionsView: View {
  @Environment(ErrorHandler.self) var errorHandler
  @StateObject private var model: CollectionsModel

  init(model: @autoclosure @escaping () -> CollectionsModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    @Bindable var errorHandler = errorHandler
    content
      .platformNavigationTitle("Collections")
      .background(Color.KinoPub.background)
      .task { await model.fetch() }
      .refreshable { await model.refresh() }
      .handleError(state: $errorHandler.state)
  }

  @ViewBuilder
  private var content: some View {
    if model.cards.isEmpty && !model.isLoaded {
      LoadingIndicatorView()
    } else if model.cards.isEmpty && model.loadFailed {
      UnavailableView(title: "Couldn't Load",
                      systemImage: "wifi.exclamationmark",
                      message: model.loadError?.userFacingMessage ?? "Check your connection and try again.".localized,
                      retryTitle: "Try Again",
                      onRetry: {
        Task { await model.refresh() }
      })
    } else if model.cards.isEmpty {
      UnavailableView(title: "No Results", systemImage: "rectangle.stack")
    } else {
      MediaCardsListView(
        cards: model.cards,
        onLoadMoreContent: { card in model.loadMoreIfNeeded(after: card) },
        navigationLinkProvider: { card in
          Route.collection(CollectionMediaCard.routeCollection(from: card))
        },
        paginationError: model.paginationError,
        onRetryPagination: { model.retryPagination() }
      )
    }
  }

  static func make(context: AppContextProtocol,
                   authState: AuthState,
                   errorHandler: ErrorHandler) -> CollectionsView {
    CollectionsView(model: CollectionsModel(collectionsService: context.collectionsService,
                                            authState: authState,
                                            errorHandler: errorHandler))
  }
}

struct CollectionsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      CollectionsView(model: CollectionsModel(collectionsService: CollectionsServiceMock(),
                                              authState: AuthState(authService: AuthorizationServiceMock(),
                                                                   accessTokenService: AccessTokenServiceMock()),
                                              errorHandler: ErrorHandler()))
    }
  }
}
