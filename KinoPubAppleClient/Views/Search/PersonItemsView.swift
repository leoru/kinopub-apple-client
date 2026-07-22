//
//  PersonItemsView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Everything kino.pub has under one name, reached from the credits on an item page.
/// The web client calls this a search with `mode=actor`; it is the same `/v1/items`
/// listing as the library, narrowed to a person, so it is built from the same catalog
/// and grid — sorting only, since a filter bar on a couple of dozen credits is noise.
struct PersonItemsView: View {

  private let person: MediaPerson
  private let linkProvider: NavigationLinkProvider

  @EnvironmentObject var errorHandler: ErrorHandler
  @StateObject private var catalog: LibraryCatalog

  init(person: MediaPerson,
       linkProvider: NavigationLinkProvider,
       catalog: @autoclosure @escaping () -> LibraryCatalog) {
    self.person = person
    self.linkProvider = linkProvider
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      grid
    }
    .background(Color.KinoPub.background)
    .platformNavigationTitle(person.name)
    .task {
      await catalog.load()
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: Self.spacing) {
      VStack(alignment: .leading, spacing: 4) {
        Text(person.name)
          .font(Self.nameFont)
          .foregroundStyle(Color.KinoPub.text)
        Text(LocalizedStringKey(person.role.titleKey))
          .font(Self.roleFont)
          .foregroundStyle(Color.KinoPub.subtitle)
      }

      Spacer(minLength: Self.spacing)

      LibrarySortMenu(catalog: catalog)
        .font(LibraryFiltersBar.font)
    }
    .padding(.horizontal, Self.horizontalInset)
    .padding(.vertical, Self.verticalPadding)
  }

  /// Built the same way from every navigation stack; only the routes differ.
  static func make(person: MediaPerson,
                   linkProvider: NavigationLinkProvider,
                   context: AppContextProtocol,
                   authState: AuthState,
                   errorHandler: ErrorHandler) -> PersonItemsView {
    PersonItemsView(person: person,
                    linkProvider: linkProvider,
                    catalog: LibraryCatalog(itemsService: context.contentService,
                                            authState: authState,
                                            errorHandler: errorHandler,
                                            filter: LibraryFilter(person: person)))
  }

  private var grid: some View {
    GeometryReader { geometryProxy in
      ContentItemsListView(width: geometryProxy.size.width,
                           items: $catalog.items,
                           onLoadMoreContent: { catalog.loadMoreContent(after: $0) },
                           onRefresh: { await catalog.refresh() },
                           navigationLinkProvider: { linkProvider.link(for: $0) })
    }
  }

#if os(tvOS)
  static let spacing: CGFloat = 24
  static let horizontalInset: CGFloat = 80
  static let verticalPadding: CGFloat = 16
  static let nameFont: Font = .system(size: 44, weight: .bold)
  static let roleFont: Font = .system(size: 24, weight: .regular)
#else
  static let spacing: CGFloat = 12
  static let horizontalInset: CGFloat = 16
  static let verticalPadding: CGFloat = 8
  static let nameFont: Font = .system(size: 24, weight: .bold)
  static let roleFont: Font = .system(size: 14, weight: .regular)
#endif
}
