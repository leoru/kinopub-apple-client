//
//  UILabRoot.swift
//  KinoPubAppleClient
//
//  DEBUG-only UI lab windows for A/B’ing Apple-like chrome before promoting
//  into the real shell. Delete this folder once a candidate ships.
//

#if DEBUG
import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Window identity

enum UILabWindow {
  static let id = "ui-lab"
}

/// Sidebar / shell candidates under test.
enum UILabChrome: String, Codable, Hashable, CaseIterable, Identifiable {
  case adaptableSidebar
  case navigationSplit

  var id: String { rawValue }

  var title: String {
    switch self {
    case .adaptableSidebar: return "Adaptable Sidebar"
    case .navigationSplit: return "Navigation Split"
    }
  }

  var windowTitle: String {
    "UI Lab — \(title)"
  }

  var other: UILabChrome {
    switch self {
    case .adaptableSidebar: return .navigationSplit
    case .navigationSplit: return .adaptableSidebar
    }
  }
}

// MARK: - Root

/// Hosts the active chrome candidate and toolbar/menu controls to switch
/// between them (or open the other chrome in a sibling window).
struct UILabRoot: View {
  @State private var chrome: UILabChrome

  init(initialChrome: UILabChrome = .navigationSplit) {
    _chrome = State(initialValue: initialChrome)
  }

  var body: some View {
#if os(macOS)
    Group {
      switch chrome {
      case .adaptableSidebar:
        UILabAdaptableShell(chrome: $chrome)
      case .navigationSplit:
        UILabSplitShell(chrome: $chrome)
      }
    }
#else
    SystemTypeStylesCatalogView()
#endif
  }
}

// MARK: - Shared chrome controls

private struct UILabChromeToolbar: ToolbarContent {
  @Binding var chrome: UILabChrome
#if os(macOS)
  @Environment(\.openWindow) private var openWindow
#endif

  var body: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      Picker("Sidebar", selection: $chrome) {
        ForEach(UILabChrome.allCases) { candidate in
          Text(candidate.title).tag(candidate)
        }
      }
      .pickerStyle(.segmented)
      .help("Switch the lab shell in this window")
    }

#if os(macOS)
    ToolbarItem(placement: .automatic) {
      Button {
        openWindow(id: UILabWindow.id, value: chrome.other)
      } label: {
        Label("Open \(chrome.other.title)", systemImage: "macwindow.badge.plus")
      }
      .help("Open the other sidebar candidate in a new window for side-by-side comparison")
    }
#endif
  }
}

// MARK: - Shell A: TabView(.sidebarAdaptable) — mirrors production macOS

#if os(macOS)
private enum UILabTab: Hashable {
  case search, home, movies, series, watchlist, typography
}

private struct UILabAdaptableShell: View {
  @Binding var chrome: UILabChrome
  @State private var tab: UILabTab = .search

  var body: some View {
    TabView(selection: $tab) {
      TabSection("Browse") {
        Tab(value: UILabTab.search, role: .search) {
          NavigationStack {
            UILabSearchSurface(chromeLabel: UILabChrome.adaptableSidebar.title)
              .toolbar { UILabChromeToolbar(chrome: $chrome) }
          }
        } label: {
          Label("Search", systemImage: "magnifyingglass")
        }

        Tab("For You", systemImage: "play.fill", value: UILabTab.home) {
          NavigationStack {
            UILabPlaceholderPage(
              title: "For You",
              note: "Production-shaped adaptable sidebar tab."
            )
            .toolbar { UILabChromeToolbar(chrome: $chrome) }
          }
        }

        Tab("Movies", systemImage: "movieclapper", value: UILabTab.movies) {
          NavigationStack {
            UILabPlaceholderPage(title: "Movies", note: "Catalog stand-in.")
              .toolbar { UILabChromeToolbar(chrome: $chrome) }
          }
        }

        Tab("Series", systemImage: "tv", value: UILabTab.series) {
          NavigationStack {
            UILabPlaceholderPage(title: "Series", note: "Catalog stand-in.")
              .toolbar { UILabChromeToolbar(chrome: $chrome) }
          }
        }
      }

      TabSection("Design") {
        Tab("Type Styles", systemImage: "textformat", value: UILabTab.typography) {
          NavigationStack {
            SystemTypeStylesCatalogView()
              .toolbar { UILabChromeToolbar(chrome: $chrome) }
          }
        }
      }

      TabSection("Library") {
        Tab("Watchlist", systemImage: "bookmark.fill", value: UILabTab.watchlist) {
          NavigationStack {
            UILabPlaceholderPage(title: "Watchlist", note: "Library section stand-in.")
              .toolbar { UILabChromeToolbar(chrome: $chrome) }
          }
        }
      }
    }
    .tabViewStyle(.sidebarAdaptable)
  }
}

// MARK: - Shell B: NavigationSplitView — always-visible sidebar, no hide control

private enum UILabSplitItem: String, Hashable, CaseIterable, Identifiable {
  case search, home, movies, series, watchlist, typography

  var id: String { rawValue }

  var title: String {
    switch self {
    case .search: return "Search"
    case .home: return "For You"
    case .movies: return "Movies"
    case .series: return "Series"
    case .watchlist: return "Watchlist"
    case .typography: return "Type Styles"
    }
  }

  var systemImage: String {
    switch self {
    case .search: return "magnifyingglass"
    case .home: return "play.fill"
    case .movies: return "movieclapper"
    case .series: return "tv"
    case .watchlist: return "bookmark.fill"
    case .typography: return "textformat"
    }
  }
}

private struct UILabSplitShell: View {
  @Binding var chrome: UILabChrome
  @State private var selection: UILabSplitItem? = .search
  /// Locked on — sidebar never collapses. Toggle chrome removed below.
  @State private var columnVisibility = NavigationSplitViewVisibility.all

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      List(selection: $selection) {
        Section("Browse") {
          ForEach([UILabSplitItem.search, .home, .movies, .series]) { item in
            Label(item.title, systemImage: item.systemImage)
              .tag(item)
          }
        }
        Section("Library") {
          Label(UILabSplitItem.watchlist.title, systemImage: UILabSplitItem.watchlist.systemImage)
            .tag(UILabSplitItem.watchlist)
        }
        Section("Design") {
          Label(UILabSplitItem.typography.title, systemImage: UILabSplitItem.typography.systemImage)
            .tag(UILabSplitItem.typography)
        }
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
      .toolbar(removing: .sidebarToggle)
      .navigationTitle("KinoPub Lab")
    } detail: {
      NavigationStack {
        detail
          .toolbar { UILabChromeToolbar(chrome: $chrome) }
      }
    }
    .navigationSplitViewStyle(.balanced)
    // Belt-and-braces: if anything tries to collapse the sidebar, snap it back.
    .onChange(of: columnVisibility) { _, newValue in
      if newValue != .all {
        columnVisibility = .all
      }
    }
  }

  @ViewBuilder
  private var detail: some View {
    switch selection ?? .search {
    case .search:
      UILabSearchSurface(chromeLabel: UILabChrome.navigationSplit.title)
    case .home:
      UILabPlaceholderPage(title: "For You", note: "Split-view detail — sidebar stays put.")
    case .movies:
      UILabPlaceholderPage(title: "Movies", note: "Split-view detail.")
    case .series:
      UILabPlaceholderPage(title: "Series", note: "Split-view detail.")
    case .watchlist:
      UILabPlaceholderPage(title: "Watchlist", note: "Split-view detail.")
    case .typography:
      SystemTypeStylesCatalogView()
    }
  }
}
#endif

// MARK: - Placeholder pages

private struct UILabPlaceholderPage: View {
  let title: String
  let note: String

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: "flask")
    } description: {
      Text(note)
    }
    .platformNavigationTitle(title)
  }
}

#Preview("UI Lab") {
  UILabRoot()
}

#if os(macOS)
#Preview("UI Lab — Adaptable Sidebar") {
  UILabRoot(initialChrome: .adaptableSidebar)
}
#endif

#endif
