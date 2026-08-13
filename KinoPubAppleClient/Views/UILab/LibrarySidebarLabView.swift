//
//  LibrarySidebarLabView.swift
//  KinoPubAppleClient
//
//  DEBUG-only. A/B for the shape docs/archive/plans/library-sidebar.md leaves open:
//  `NavigationSplitView` vs `TabView(.sidebarAdaptable)` nested **inside** the
//  Library tab of a plain top-level `TabView(.tabBarOnly)` — the outer chrome stays
//  exactly as shipped; only what sits inside the Library tab changes. This is the
//  tvOS-focus probe the plan calls "Open risk" (NavigationSplitView) with its named
//  fallback (nested TabView(.sidebarAdaptable)) built side by side for comparison.
//
//  Delete alongside Views/UILab/ once a candidate ships.
//

#if DEBUG
import SwiftUI

// MARK: - Candidates

enum LibraryLabChrome: String, CaseIterable, Identifiable {
  case nestedSplit
  case nestedTabView

  var id: String { rawValue }

  var title: String {
    switch self {
    case .nestedSplit: return "Nested Split"
    case .nestedTabView: return "Nested Sidebar Tab"
    }
  }
}

// MARK: - Mock data

/// Shapes match the sketch in the plan doc — no networking, this is chrome only.
private struct LibraryLabFolder: Identifiable, Hashable {
  let id: Int
  let title: String
  let count: Int
}

private enum LibraryLabMock {
  static let folders: [LibraryLabFolder] = [
    LibraryLabFolder(id: 1, title: "List 1", count: 525),
    LibraryLabFolder(id: 2, title: "List 2", count: 46),
    LibraryLabFolder(id: 3, title: "Documentary", count: 128),
    LibraryLabFolder(id: 4, title: "Drama", count: 342),
    LibraryLabFolder(id: 5, title: "Horror", count: 87),
    LibraryLabFolder(id: 6, title: "Kids & Family", count: 54),
  ]
}

private enum LibraryLabFixedSection: CaseIterable, Hashable {
  case watchlist, movies, tvShows

  var title: String {
    switch self {
    case .watchlist: return "Watchlist"
    case .movies: return "Movies"
    case .tvShows: return "TV Shows"
    }
  }

  var systemImage: String {
    switch self {
    case .watchlist: return "star"
    case .movies: return "movieclapper"
    case .tvShows: return "tv"
    }
  }
}

private enum LibraryLabItem: Hashable {
  case fixed(LibraryLabFixedSection)
  case folder(Int)

  var title: String {
    switch self {
    case .fixed(let section): return section.title
    case .folder(let id): return LibraryLabMock.folders.first { $0.id == id }?.title ?? "Bookmark"
    }
  }
}

// MARK: - Root

struct LibrarySidebarLabView: View {
  @State private var chrome: LibraryLabChrome = .nestedSplit

  var body: some View {
    VStack(spacing: 0) {
      Picker("Candidate", selection: $chrome) {
        ForEach(LibraryLabChrome.allCases) { candidate in
          Text(candidate.title).tag(candidate)
        }
      }
      .pickerStyle(.segmented)
      .padding()

      switch chrome {
      case .nestedSplit:
        LibraryLabOuterShell { LibraryLabNestedSplit() }
      case .nestedTabView:
        LibraryLabOuterShell { LibraryLabNestedTabView() }
      }
    }
    .platformNavigationTitle("Library Sidebar Lab")
  }
}

// MARK: - Outer shell — mirrors the shipped top-level TabView(.tabBarOnly)

/// The thing under test is only what's inside the Library tab. Home / Movies / TV
/// Shows / Settings are inert stand-ins so the Library tab sits in the same outer
/// chrome it ships in today, not a hypothetical collapsed app-level sidebar.
private struct LibraryLabOuterShell<LibraryContent: View>: View {
  @ViewBuilder var libraryContent: () -> LibraryContent

  var body: some View {
    TabView {
      Tab("Home", systemImage: "play.fill") {
        LibraryLabPlaceholder(title: "Home")
      }
      Tab("Movies", systemImage: "movieclapper") {
        LibraryLabPlaceholder(title: "Movies")
      }
      Tab("TV Shows", systemImage: "tv") {
        LibraryLabPlaceholder(title: "TV Shows")
      }
      Tab("Library", systemImage: "books.vertical") {
        libraryContent()
      }
      Tab("Settings", systemImage: "gear") {
        LibraryLabPlaceholder(title: "Settings")
      }
    }
    .tabViewStyle(.tabBarOnly)
  }
}

private struct LibraryLabPlaceholder: View {
  let title: String

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: "flask")
    } description: {
      Text("Outer shell stand-in — not under test.")
    }
  }
}

// MARK: - Candidate A: NavigationSplitView nested in the Library tab
// docs/archive/plans/library-sidebar.md phase 2.

private struct LibraryLabNestedSplit: View {
  @State private var selection: LibraryLabItem? = .fixed(.watchlist)

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Section {
          ForEach(LibraryLabFixedSection.allCases, id: \.self) { section in
            Label(section.title, systemImage: section.systemImage)
              .tag(LibraryLabItem.fixed(section))
          }
        }
        Section("Bookmarks") {
          ForEach(LibraryLabMock.folders) { folder in
            Label {
              HStack {
                Text(folder.title)
                Spacer()
                Text("\(folder.count)")
                  .foregroundStyle(.secondary)
                  .monospacedDigit()
              }
            } icon: {
              Image(systemName: "bookmark")
            }
            .tag(LibraryLabItem.folder(folder.id))
          }
        }
      }
#if os(tvOS)
      .listStyle(.plain)
#else
      .listStyle(.sidebar)
#endif
#if os(macOS)
      .toolbar(removing: .sidebarToggle)
#endif
      .navigationTitle("Library")
    } detail: {
      LibraryLabDetail(title: selection?.title ?? "Library")
    }
  }
}

// MARK: - Candidate B: TabView(.sidebarAdaptable) nested in the Library tab
// docs/archive/plans/library-sidebar.md's named fallback if split-view focus doesn't
// carry on tvOS.

private struct LibraryLabNestedTabView: View {
  @State private var selection: LibraryLabItem = .fixed(.watchlist)

  var body: some View {
    TabView(selection: $selection) {
      ForEach(LibraryLabFixedSection.allCases, id: \.self) { section in
        Tab(section.title, systemImage: section.systemImage, value: LibraryLabItem.fixed(section)) {
          LibraryLabDetail(title: section.title)
        }
      }

      TabSection("Bookmarks") {
        ForEach(LibraryLabMock.folders) { folder in
          Tab(folder.title, systemImage: "bookmark", value: LibraryLabItem.folder(folder.id)) {
            LibraryLabDetail(title: folder.title)
          }
        }
      }
    }
    .tabViewStyle(.sidebarAdaptable)
  }
}

// MARK: - Shared detail

private struct LibraryLabDetail: View {
  let title: String

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: "square.grid.2x2")
    } description: {
      Text("Poster grid stand-in.")
    }
    .platformNavigationTitle(title)
  }
}

#Preview("Library Sidebar Lab") {
  LibrarySidebarLabView()
}

#endif
