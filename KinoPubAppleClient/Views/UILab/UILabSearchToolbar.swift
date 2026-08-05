//
//  UILabSearchToolbar.swift
//  KinoPubAppleClient
//
//  DEBUG-only search toolbar experiments: principal search field + two filter
//  presentations (floating accessory chips vs compact toolbar menus).
//

#if DEBUG
import SwiftUI
import KinoPubUI

// MARK: - Filter presentation axis

enum UILabFilterPresentation: String, CaseIterable, Identifiable, Codable, Hashable {
  case floatingAccessory
  case toolbarMenus

  var id: String { rawValue }

  var title: String {
    switch self {
    case .floatingAccessory: return "Accessory Chips"
    case .toolbarMenus: return "Toolbar Menus"
    }
  }
}

// MARK: - Mock filter model

enum UILabSearchScope: String, CaseIterable, Identifiable, Hashable {
  case allResults, movies, series, people

  var id: String { rawValue }

  var title: String {
    switch self {
    case .allResults: return "All Results"
    case .movies: return "Movies"
    case .series: return "Series"
    case .people: return "People"
    }
  }

  var mockCount: Int {
    switch self {
    case .allResults: return 973
    case .movies: return 412
    case .series: return 318
    case .people: return 243
    }
  }
}

enum UILabContentType: String, CaseIterable, Identifiable, Hashable {
  case movie, series

  var id: String { rawValue }

  var title: String {
    switch self {
    case .movie: return "Movie"
    case .series: return "Series"
    }
  }

  var icon: String {
    switch self {
    case .movie: return "movieclapper"
    case .series: return "tv"
    }
  }
}

enum UILabFilterChip: String, CaseIterable, Identifiable, Hashable {
  case all, featured, fourK, hdr, subtitles

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all: return "All"
    case .featured: return "Featured"
    case .fourK: return "4K"
    case .hdr: return "HDR"
    case .subtitles: return "Subtitles"
    }
  }

  var icon: String {
    switch self {
    case .all: return "square.grid.2x2"
    case .featured: return "star.fill"
    case .fourK: return "4k.tv"
    case .hdr: return "sparkles.tv"
    case .subtitles: return "captions.bubble"
    }
  }
}

enum UILabSortOrder: String, CaseIterable, Identifiable, Hashable {
  case added, title, year, rating

  var id: String { rawValue }

  var title: String {
    switch self {
    case .added: return "Date Added"
    case .title: return "Title"
    case .year: return "Year"
    case .rating: return "Rating"
    }
  }
}

struct UILabSearchFilters: Equatable {
  var scope: UILabSearchScope = .allResults
  var chip: UILabFilterChip = .all
  var contentType: UILabContentType?
  var genre: String?
  var country: String?
  var year: String?
  var sort: UILabSortOrder = .added

  static let mockGenres = ["Action", "Drama", "Comedy", "Sci‑Fi", "Horror"]
  static let mockCountries = ["USA", "Russia", "UK", "France", "Japan"]
  static let mockYears = ["2020s", "2010s", "2000s", "1990s", "Classic"]

  var hasSecondaryFilters: Bool {
    contentType != nil || genre != nil || country != nil || year != nil
  }

  var summary: String {
    [
      scope.title,
      chip == .all ? nil : chip.title,
      contentType?.title,
      genre,
      country,
      year,
      sort.title
    ]
    .compactMap { $0 }
    .joined(separator: " · ")
  }
}

// MARK: - Search surface

struct UILabSearchSurface: View {
  let chromeLabel: String

  @State private var text = ""
  @FocusState private var searchFocused: Bool
  @State private var filters = UILabSearchFilters()
  @State private var filterPresentation: UILabFilterPresentation = .floatingAccessory

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        diagnosticsHeader

        if !filters.summary.isEmpty {
          LabeledContent("Active filters") {
            Text(filters.summary)
              .foregroundStyle(.secondary)
              .font(.callout)
          }
        }

        ForEach(0..<24, id: \.self) { index in
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.accentColor.opacity(0.22))
            .frame(height: 64)
            .overlay(alignment: .leading) {
              Text("Row \(index)")
                .padding(.horizontal, 16)
            }
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
#if os(macOS)
    .searchable(
      text: $text,
      placement: .toolbarPrincipal,
      prompt: "Shows, Movies, and More"
    )
    .searchFocused($searchFocused)
    .toolbar {
      UILabFilterPresentationPicker(selection: $filterPresentation)

      if filterPresentation == .toolbarMenus {
        UILabToolbarFilterMenus(filters: $filters)
      }

      if filterPresentation == .floatingAccessory {
        ToolbarItem(placement: .accessoryBar(id: "lab-search-filters")) {
          UILabFloatingFilterBar(filters: $filters)
        }
      }
    }
    .toolbar(removing: .title)
    .navigationTitle("")
    .background(UILabToolbarProbe())
#else
    .searchable(text: $text, placement: .automatic, prompt: "Shows, Movies, and More")
    .platformNavigationTitle("Search")
#endif
    .task {
#if os(macOS)
      try? await Task.sleep(for: .milliseconds(450))
      if text.isEmpty { searchFocused = true }
#endif
    }
  }

  private var diagnosticsHeader: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Browse Categories")
        .font(.title2.bold())

      LabeledContent("Chrome") {
        Text(chromeLabel).foregroundStyle(.secondary)
      }
      LabeledContent("Filter axis") {
        Text(filterPresentation.title).foregroundStyle(.secondary)
      }
      LabeledContent("Query") {
        Text(text.isEmpty ? "—" : text)
          .foregroundStyle(.secondary)
          .monospaced()
      }
      LabeledContent("Search focused") {
        Text(searchFocused ? "YES" : "no")
          .foregroundStyle(searchFocused ? .green : .orange)
          .fontWeight(.semibold)
      }

      Text(filterPresentation == .floatingAccessory
           ? "Axis: toolbarPrincipal search + accessoryBar glass chips (Photos-style)."
           : "Axis: toolbarPrincipal search + trailing scope Menu + filter menus (Settings-style).")
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

// MARK: - Presentation picker (lab meta-control)

#if os(macOS)
struct UILabFilterPresentationPicker: ToolbarContent {
  @Binding var selection: UILabFilterPresentation

  var body: some ToolbarContent {
    ToolbarItem(placement: .status) {
      Picker("Filters", selection: $selection) {
        ForEach(UILabFilterPresentation.allCases) { style in
          Text(style.title).tag(style)
        }
      }
      .pickerStyle(.segmented)
      .frame(maxWidth: 280)
      .help("Switch between floating accessory chips and compact toolbar menus")
    }
  }
}

// MARK: - Variant A: floating accessory glass chips

struct UILabFloatingFilterBar: View {
  @Binding var filters: UILabSearchFilters

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(UILabFilterChip.allCases) { chip in
          chipButton(chip)
        }

        divider

        secondaryMenu(
          title: filters.contentType?.title ?? "Type",
          icon: filters.contentType?.icon ?? "square.grid.2x2",
          isActive: filters.contentType != nil
        ) {
          Button("Any") { filters.contentType = nil }
          Divider()
          ForEach(UILabContentType.allCases) { type in
            Button(type.title) { filters.contentType = type }
          }
        }

        secondaryMenu(
          title: filters.genre ?? "Genre",
          icon: "theatermasks",
          isActive: filters.genre != nil
        ) {
          Button("Any") { filters.genre = nil }
          Divider()
          ForEach(UILabSearchFilters.mockGenres, id: \.self) { genre in
            Button(genre) { filters.genre = genre }
          }
        }

        secondaryMenu(
          title: filters.country ?? "Country",
          icon: "globe",
          isActive: filters.country != nil
        ) {
          Button("Any") { filters.country = nil }
          Divider()
          ForEach(UILabSearchFilters.mockCountries, id: \.self) { country in
            Button(country) { filters.country = country }
          }
        }

        secondaryMenu(
          title: filters.year ?? "Years",
          icon: "calendar",
          isActive: filters.year != nil
        ) {
          Button("Any") { filters.year = nil }
          Divider()
          ForEach(UILabSearchFilters.mockYears, id: \.self) { year in
            Button(year) { filters.year = year }
          }
        }

        if filters.hasSecondaryFilters || filters.chip != .all {
          Button {
            filters = UILabSearchFilters()
          } label: {
            Label("Clear", systemImage: "xmark")
          }
          .buttonStyle(.accessoryBarAction)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
    }
  }

  private var divider: some View {
    Divider()
      .frame(height: 20)
      .padding(.horizontal, 2)
  }

  @ViewBuilder
  private func chipButton(_ chip: UILabFilterChip) -> some View {
    let isSelected = filters.chip == chip
    Button {
      filters.chip = chip
    } label: {
      Label(chip.title, systemImage: chip.icon)
        .labelStyle(.titleAndIcon)
    }
    .modifier(UILabGlassChipStyle(isProminent: isSelected))
  }

  @ViewBuilder
  private func secondaryMenu(
    title: String,
    icon: String,
    isActive: Bool,
    @ViewBuilder content: () -> some View
  ) -> some View {
    Menu(content: content) {
      Label(title, systemImage: icon)
        .labelStyle(.titleAndIcon)
    }
    .modifier(UILabGlassChipStyle(isProminent: isActive))
  }
}

// MARK: - Variant B: toolbar menus (Settings-style)

struct UILabToolbarFilterMenus: ToolbarContent {
  @Binding var filters: UILabSearchFilters

  var body: some ToolbarContent {
    ToolbarItem(placement: .automatic) {
      scopeMenu
    }

    ToolbarItemGroup(placement: .automatic) {
      compactMenu(
        title: filters.contentType?.title ?? "Type",
        icon: filters.contentType?.icon ?? "square.grid.2x2",
        isActive: filters.contentType != nil
      ) {
        Button("Any") { filters.contentType = nil }
        Divider()
        ForEach(UILabContentType.allCases) { type in
          Button(type.title) { filters.contentType = type }
        }
      }

      compactMenu(
        title: filters.genre ?? "Genre",
        icon: "theatermasks",
        isActive: filters.genre != nil
      ) {
        Button("Any") { filters.genre = nil }
        Divider()
        ForEach(UILabSearchFilters.mockGenres, id: \.self) { genre in
          Button(genre) { filters.genre = genre }
        }
      }

      compactMenu(
        title: filters.country ?? "Country",
        icon: "globe",
        isActive: filters.country != nil
      ) {
        Button("Any") { filters.country = nil }
        Divider()
        ForEach(UILabSearchFilters.mockCountries, id: \.self) { country in
          Button(country) { filters.country = country }
        }
      }

      compactMenu(
        title: filters.year ?? "Years",
        icon: "calendar",
        isActive: filters.year != nil
      ) {
        Button("Any") { filters.year = nil }
        Divider()
        ForEach(UILabSearchFilters.mockYears, id: \.self) { year in
          Button(year) { filters.year = year }
        }
      }

      compactMenu(
        title: filters.sort.title,
        icon: "arrow.up.arrow.down",
        isActive: false
      ) {
        ForEach(UILabSortOrder.allCases) { order in
          Button(order.title) { filters.sort = order }
        }
      }

      if filters.hasSecondaryFilters {
        Button {
          filters.contentType = nil
          filters.genre = nil
          filters.country = nil
          filters.year = nil
        } label: {
          Label("Clear", systemImage: "xmark")
        }
        .help("Clear secondary filters")
      }
    }
  }

  private var scopeMenu: some View {
    Menu {
      ForEach(UILabSearchScope.allCases) { scope in
        Button {
          filters.scope = scope
        } label: {
          if filters.scope == scope {
            Label("\(scope.title) (\(scope.mockCount))", systemImage: "checkmark")
          } else {
            Text("\(scope.title) (\(scope.mockCount))")
          }
        }
      }
    } label: {
      HStack(spacing: 6) {
        Text("\(filters.scope.title) (\(filters.scope.mockCount))")
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .buttonStyle(.glass)
    .buttonBorderShape(.capsule)
    .controlSize(.regular)
  }

  @ViewBuilder
  private func compactMenu(
    title: String,
    icon: String,
    isActive: Bool,
    @ViewBuilder content: () -> some View
  ) -> some View {
    Menu(content: content) {
      Label(title, systemImage: icon)
        .labelStyle(.iconOnly)
    }
    .help(title)
    .modifier(UILabGlassChipStyle(isProminent: isActive, iconOnly: true))
  }
}
#endif

// MARK: - Shared glass chip styling

#if os(macOS)
private struct UILabGlassChipStyle: ViewModifier {
  var isProminent: Bool
  var iconOnly: Bool = false

  func body(content: Content) -> some View {
    Group {
      if isProminent {
        content
          .buttonStyle(.glassProminent)
          .tint(Color.KinoPub.accent)
      } else {
        content
          .buttonStyle(.glass)
      }
    }
    .buttonBorderShape(.capsule)
    .controlSize(iconOnly ? .small : .regular)
  }
}
#endif

#if os(macOS)
/// Prints the live NSToolbar once so we can confirm principal search wiring.
struct UILabToolbarProbe: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      guard let toolbar = view.window?.toolbar else {
        print("UILAB: no toolbar")
        return
      }
      print("UILAB: toolbar class=\(type(of: toolbar)) centered=\(toolbar.centeredItemIdentifiers)")
      for item in toolbar.items {
        print("UILAB: item id=\(item.itemIdentifier.rawValue) class=\(type(of: item))")
      }
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif

#endif
