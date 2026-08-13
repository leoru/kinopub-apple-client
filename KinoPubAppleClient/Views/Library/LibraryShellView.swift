//
//  LibraryShellView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

#if os(macOS) || os(tvOS)
/// Library: sidebar of sections, grid of the selected one. Sections are a product
/// decision — `ROADMAP.md`.
///
/// Both platforms lay the sidebar out as **content**, not as window/system chrome, so
/// the tab bar keeps the full width above it. On tvOS that also keeps focus honest:
/// each column is its own `focusSection`, so Left out of the grid lands in the list and
/// Right comes back, without a `NavigationSplitView` deciding when to collapse.
struct LibraryShellView: View {
  @EnvironmentObject var navigationState: NavigationState
  @Environment(ErrorHandler.self) var errorHandler
  @Environment(\.appContext) var appContext
  @Environment(\.openURL) private var openURL

  @StateObject private var model: LibraryModel
  @StateObject private var catalog: LibrarySectionCatalog
  @StateObject private var cardMenu = MediaCardMenuCoordinator()

  init(model: @autoclosure @escaping () -> LibraryModel,
       catalog: @autoclosure @escaping () -> LibrarySectionCatalog) {
    _model = StateObject(wrappedValue: model())
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    @Bindable var errorHandler = errorHandler
    // Deliberately NOT a `NavigationSplitView`. On macOS that makes the sidebar window
    // chrome: it runs full height beside the title bar, so the tab bar and the search
    // field get pushed into the detail half and the traffic lights end up sitting on
    // the sidebar. Here the sidebar is content — the chrome spans the full width above
    // it — which is also why there is no collapse control left to remove.
    //
    // The stack wraps sidebar AND detail together, not just detail: every other tab's
    // `NavigationStack` spans its whole content area, so a pushed title's detail page
    // covers the full tab. A stack scoped to only the detail pane would leave that
    // pane's width beside a sidebar that never goes anywhere — section switching is
    // separate state (`model.selection`), not a stack push, so it is unaffected by
    // where the stack sits.
    RouteStack(tab: .library) {
      HStack(spacing: 0) {
        sidebar
        detail
          .frame(maxWidth: .infinity)
      }
    }
    .task {
      cardMenu.bind(errorHandler: errorHandler)
      await model.load()
    }
    .task { await cardMenu.refreshFolders() }
    // Section switches are cheap when the cache is warm — `activate` paints from the
    // store first and only refetches past the TTL.
    .task(id: model.selection) {
      await catalog.activate(model.selection)
    }
    .alert("New Bookmark", isPresented: $model.isCreatingFolder) {
      TextField("Folder name", text: $model.newFolderName)
      Button("Create") { model.confirmNewFolder() }
      Button("Cancel", role: .cancel) { model.isCreatingFolder = false }
    }
    .handleError(state: $errorHandler.state)
  }

  // MARK: - Sidebar

#if os(macOS)
  private var sidebar: some View {
    List(selection: selectionBinding) {
      Section {
        ForEach(LibrarySection.fixed, id: \.self) { section in
          row(for: section)
            .tag(section)
        }
      }

      Section("Bookmarks") {
        ForEach(model.folders, id: \.id) { folder in
          row(for: .folder(folder.id))
            .tag(LibrarySection.folder(folder.id))
            .contextMenu {
              Button("Delete Bookmark", role: .destructive) {
                model.deleteFolder(id: folder.id)
              }
            }
        }

        Button {
          model.promptNewFolder()
        } label: {
          Label("Create Bookmark", systemImage: "plus")
        }
        .buttonStyle(.plain)
      }
    }
    // No material behind the sidebar: it shares the window's background with the grid
    // so the two columns read as one surface, not as chrome bolted onto content.
    .scrollContentBackground(.hidden)
    .listStyle(.sidebar)
    .frame(width: 240)
  }

  /// `List` writes straight to the binding, so persistence has to hang off the setter
  /// rather than off a button action — there is no button.
  private var selectionBinding: Binding<LibrarySection?> {
    Binding(
      get: { model.selection },
      set: { newValue in
        guard let newValue else { return }  // clicking empty space must not clear the pane
        model.select(newValue)
      }
    )
  }
#endif

#if os(tvOS)
  /// A plain `List` of list items — the shape tvOS ships in its own sidebar template,
  /// not a hand-rolled stack of buttons. Rows stay `Button`s because selection has to
  /// follow the click: on tvOS focus sweeps every row you pass on the way down, and
  /// selection-follows-focus would refetch each section in turn.
  private var sidebar: some View {
    List {
      Section {
        ForEach(LibrarySection.fixed, id: \.self) { section in
          sidebarButton(for: section)
        }
      }

      Section("Bookmarks") {
        ForEach(model.folders, id: \.id) { folder in
          sidebarButton(for: .folder(folder.id))
        }

        Button {
          model.promptNewFolder()
        } label: {
          Label("Create Bookmark", systemImage: "plus")
        }
      }
    }
    .listStyle(.plain)
    .frame(width: 420)
    .focusSection()
  }

  private func sidebarButton(for section: LibrarySection) -> some View {
    Button {
      model.select(section)
    } label: {
      row(for: section)
    }
  }
#endif

  private func row(for section: LibrarySection) -> some View {
    HStack {
      Label(model.title(for: section), systemImage: section.systemImage)
        .lineLimit(1)
      if let count = model.count(for: section) {
        Spacer()
        Text(count)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
    }
#if os(tvOS)
    // The focused row already reads as "here"; the selected one needs to stay legible
    // when focus is off in the grid.
    .fontWeight(model.selection == section ? .semibold : .regular)
#endif
  }

  // MARK: - Detail

  @ViewBuilder
  private var detail: some View {
    if model.selection == .downloads {
      // Downloads brings its own stack and its own route list — local files, not a
      // card grid, so it does not go through `LibrarySectionCatalog`. That inner stack
      // is still scoped to this pane (unchanged) — nothing downloads pushes today is
      // the kind of full-bleed page that needs to cover the sidebar.
      DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: appContext.downloadedFilesDatabase,
                                              downloadManager: appContext.downloadManager))
    } else {
      sectionContent
        .platformNavigationTitle(model.title(for: model.selection))
#if os(macOS)
        .macToolbarSearch()
#endif
#if os(tvOS)
        .focusSection()
#endif
    }
  }

  @ViewBuilder
  private var sectionContent: some View {
    if catalog.cards.isEmpty && catalog.isLoading {
      LoadingIndicatorView()
    } else if catalog.cards.isEmpty && catalog.loadFailed {
      UnavailableView(title: "Couldn't Load",
                      systemImage: "wifi.exclamationmark",
                      message: catalog.loadError?.userFacingMessage ?? "Check your connection and try again.".localized,
                      retryTitle: "Try Again",
                      onRetry: { Task { await catalog.refresh() } })
    } else if catalog.cards.isEmpty {
      UnavailableView(title: "No Results", systemImage: model.selection.systemImage)
    } else {
      MediaCardsListView(
        cards: catalog.cards,
        onLoadMoreContent: { card in catalog.loadMoreContent(after: card) },
        navigationLinkProvider: { card in Route.detailsById(card.itemID) },
        contextMenuProvider: { card in
          MediaCardContextMenus.entries(
            for: card,
            surface: .shelf,
            menu: cardMenu,
            pushRoute: { navigationState.push($0) },
            openURL: { openURL($0) }
          )
        },
        paginationError: catalog.paginationFailed,
        onRetryPagination: { catalog.retryPagination() }
      )
    }
  }
}
#endif
