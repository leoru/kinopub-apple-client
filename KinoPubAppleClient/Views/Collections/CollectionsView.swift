//
//  CollectionsView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// One shelf per curated kino.pub collection. Pushed onto whichever tab's stack
/// opened it (today: Home's "Collections" row) — no `NavigationStack` of its own,
/// same as `PersonItemsView`.
struct CollectionsView: View {
  @EnvironmentObject var navigationState: NavigationState
  @Environment(ErrorHandler.self) var errorHandler
  @Environment(\.openURL) private var openURL
  @StateObject private var model: CollectionsModel
  @StateObject private var cardMenu = MediaCardMenuCoordinator()

  init(model: @autoclosure @escaping () -> CollectionsModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    @Bindable var errorHandler = errorHandler
    content
      .platformNavigationTitle("Collections")
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
    if model.rows.isEmpty && !model.isLoaded {
      LoadingIndicatorView()
    } else if model.rows.isEmpty && model.loadFailed {
      UnavailableView(title: "Couldn't Load",
                      systemImage: "wifi.exclamationmark",
                      message: model.loadError?.userFacingMessage ?? "Check your connection and try again.".localized,
                      retryTitle: "Try Again",
                      onRetry: {
        Task { await model.refresh() }
      })
    } else if model.rows.isEmpty {
      UnavailableView(title: "No Results", systemImage: "rectangle.stack")
    } else {
      MediaRowsView(
        rows: model.rows,
        navigationLinkProvider: { card in Route.detailsById(card.itemID) },
        onRowAppear: { row in model.loadMoreIfNeeded(after: row) },
        contextMenuProvider: { card, surface in
          MediaCardContextMenus.entries(
            for: card,
            surface: surface,
            menu: cardMenu,
            pushRoute: { navigationState.push($0) },
            openURL: { openURL($0) }
          )
        }
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
