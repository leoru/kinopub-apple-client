//
//  PersonItemsView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubMetadata

/// Everything kino.pub has under one name, reached from the credits on an item page.
/// The web client calls this a search with `mode=actor`; it is the same `/v1/items`
/// listing as the library, narrowed to a person, so it is built from the same catalog
/// and grid — sorting only, since a filter bar on a couple of dozen credits is noise.
struct PersonItemsView: View {

  private let person: MediaPerson
  private let linkProvider: NavigationLinkProvider
  private let metadataService: MetadataService

  @Environment(ErrorHandler.self) var errorHandler
  @EnvironmentObject var navigationState: NavigationState
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  /// The margin the credits grid below actually landed on. Padding this page's hero and
  /// section header by a constant of their own is what put them off the first column.
  @Environment(\.shelfGridInset) private var gridInset
  @StateObject private var catalog: LibraryCatalog
  @StateObject private var cardMenu = MediaCardMenuCoordinator()
  @State private var personMetadata = PersonMetadata()
  @State private var bioExpanded = false

  init(person: MediaPerson,
       linkProvider: NavigationLinkProvider,
       metadataService: MetadataService,
       catalog: @autoclosure @escaping () -> LibraryCatalog) {
    self.person = person
    self.linkProvider = linkProvider
    self.metadataService = metadataService
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    ContentItemsListView(
      items: $catalog.items,
      onLoadMoreContent: { catalog.loadMoreContent(after: $0) },
      navigationLinkProvider: { linkProvider.link(for: $0) },
      contextMenuProvider: { item in
        MediaCardContextMenus.entries(
          for: item,
          menu: cardMenu,
          pushRoute: { navigationState.push($0) },
          openURL: { openURL($0) }
        )
      },
      emptyMessage: showsEmptyMessage ? "No Results" : nil,
      paginationError: catalog.paginationFailed,
      onRetryPagination: { catalog.retryPagination() }
    ) {
      hero
      creditsHeader
    }
    .background(Color.KinoPub.background)
    .platformNavigationTitle(person.name)
    .overlay {
      if catalog.loadFailed {
        UnavailableView(
          title: "Couldn't Load",
          systemImage: "wifi.exclamationmark",
          message: catalog.loadError?.userFacingMessage ?? "Check your connection and try again.".localized,
          retryTitle: "Try Again",
          onRetry: {
            Task { await catalog.refresh() }
          },
          secondaryTitle: "Back",
          onSecondary: { dismiss() }
        )
      } else if catalog.isLoading && catalog.items.isEmpty {
        LoadingIndicatorView(delay: .milliseconds(700))
      }
    }
    .animation(.easeInOut(duration: 0.3), value: catalog.isLoading)
    .animation(.easeInOut(duration: 0.3), value: catalog.loadFailed)
    .task {
      cardMenu.bind(errorHandler: errorHandler)
      await catalog.load()
    }
    .task { await cardMenu.refreshFolders() }
    .mediaCardNewFolderAlert(cardMenu)
    .task(id: person.tmdbPersonId) {
      guard let id = person.tmdbPersonId else { return }
      personMetadata = await metadataService.person(id: id)
    }
  }

  private var showsEmptyMessage: Bool {
    !catalog.isLoading && !catalog.loadFailed && catalog.items.isEmpty
  }

  // MARK: - Hero

  private var hero: some View {
    HStack(alignment: .top, spacing: Self.heroSpacing) {
      // Prefer the rail URL already on screen — upgrading w185 → w342 only
      // swaps the cache key and blinks the avatar for a sharper copy.
      let photoURL = person.photoURL
        ?? personMetadata.photo
        ?? ActorImageProvider.photoURL(for: person.name)
#if os(tvOS)
      // The same circle the cast rail draws. A face selected from a round lockup must
      // not arrive as a rectangle on the page it opens.
      TVUIKitPersonAvatar(name: person.name,
                          photoURL: photoURL,
                          diameter: Self.avatarDiameter)
        .frame(width: Self.avatarDiameter, height: Self.avatarDiameter)
#else
      CastAvatarView(name: person.name, photoURL: photoURL)
#endif

      VStack(alignment: .leading, spacing: 8) {
        Text(person.name)
          .font(Self.nameFont)
          .foregroundStyle(Color.KinoPub.text)

        Text(person.role.titleKey.localized)
          .font(Self.roleFont)
          .foregroundStyle(Color.KinoPub.subtitle)

        if let metaLine = metaLine, !metaLine.isEmpty {
          Text(metaLine)
            .font(Self.metaFont)
            .foregroundStyle(Color.KinoPub.subtitle)
        }

        if let biography, !biography.isEmpty {
          bioBlock(biography)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, gridInset)
    .padding(.top, Self.verticalPadding)
    .padding(.bottom, 8)
  }

  private var biography: String? {
    personMetadata.biography.flatMap { $0.isEmpty ? nil : $0 }
  }

  private var metaLine: String? {
    var parts: [String] = []
    if let birthday = personMetadata.birthday {
      parts.append(Self.birthdayFormatter.string(from: birthday))
    }
    if let place = personMetadata.placeOfBirth, !place.isEmpty {
      parts.append(place)
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  @ViewBuilder
  private func bioBlock(_ text: String) -> some View {
    let truncated = text.count > Self.bioPreviewLimit && !bioExpanded
    VStack(alignment: .leading, spacing: 4) {
      Text(truncated ? String(text.prefix(Self.bioPreviewLimit)) + "…" : text)
        .font(Self.bioFont)
        .foregroundStyle(Color.KinoPub.subtitle)
        .fixedSize(horizontal: false, vertical: true)

      if text.count > Self.bioPreviewLimit {
        Button(bioExpanded ? "Less" : "More") {
          withAnimation(.easeOut(duration: 0.2)) {
            bioExpanded.toggle()
          }
        }
        .font(Self.bioFont.weight(.semibold))
      }
    }
  }

  // MARK: - Credits row

  private var creditsHeader: some View {
    HStack(alignment: .firstTextBaseline, spacing: Self.heroSpacing) {
      SectionHeader(
        "Credits",
        count: catalog.items.isEmpty ? nil : "\(catalog.items.count)"
      )

      Spacer(minLength: Self.heroSpacing)

      LibrarySortMenu(catalog: catalog)
        .font(LibraryFiltersBar.font)
    }
    .padding(.horizontal, gridInset)
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
                    metadataService: context.metadataService,
                    catalog: LibraryCatalog(itemsService: context.contentService,
                                            authState: authState,
                                            errorHandler: errorHandler,
                                            filter: LibraryFilter(person: person)))
  }

  private static let birthdayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
  }()

#if os(tvOS)
  static let heroSpacing: CGFloat = 28
  /// A hero reads larger than a rail entry; the rail's circle is 168.
  static let avatarDiameter: CGFloat = 220
  static let verticalPadding: CGFloat = 16
  static let bioPreviewLimit = 220
  static let nameFont: Font = .system(size: 44, weight: .bold)
  static let roleFont: Font = .system(size: 24, weight: .regular)
  static let metaFont: Font = .system(size: 22, weight: .regular)
  static let bioFont: Font = .system(size: 22, weight: .regular)
  static let sectionFont: Font = .system(size: 28, weight: .semibold)
#else
  static let heroSpacing: CGFloat = 16
  static let verticalPadding: CGFloat = 8
  static let bioPreviewLimit = 160
  static let nameFont: Font = .system(size: 24, weight: .bold)
  static let roleFont: Font = .system(size: 14, weight: .regular)
  static let metaFont: Font = .system(size: 13, weight: .regular)
  static let bioFont: Font = .system(size: 14, weight: .regular)
  static let sectionFont: Font = .system(size: 17, weight: .semibold)
#endif
}
