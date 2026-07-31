//
//  LibraryFiltersBar.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Sort and filter dropdowns across the top of the library, as microiptv has them.
/// Menus rather than sheets: one click to open, one to choose, no modal to dismiss.
///
/// DESIGN: `CatalogPeriod` (`LibraryFilter.period`) is wired into `/v1/items` — add a
/// Period menu here when the filter chrome is designed (day/week/month/year).
struct LibraryFiltersBar: View {

  @ObservedObject var catalog: LibraryCatalog

  private var years: [YearRange] {
    YearRange.decades(upTo: Calendar.current.component(.year, from: Date()))
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: Self.spacing) {
        LibrarySortMenu(catalog: catalog)
        typeMenu
        genreMenu
        countryMenu
        yearMenu

        if catalog.filter.hasActiveFilters {
          Button {
            catalog.clearFilters()
          } label: {
            Label("Clear", systemImage: "xmark")
          }
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
        }
      }
      .font(Self.font)
      .padding(.horizontal, Self.horizontalInset)
      .padding(.vertical, Self.verticalPadding)
    }
  }

  // MARK: - Menus

  private var typeMenu: some View {
    Self.menu(label: catalog.filter.contentType.map { LocalizedStringKey($0.title) } ?? "Type",
              icon: "square.grid.2x2",
              isActive: catalog.filter.contentType != nil) {
      Button {
        catalog.update { $0.contentType = nil }
      } label: {
        Self.checkmarkLabel("Any", selected: catalog.filter.contentType == nil)
      }
      ForEach(MediaType.allCases) { type in
        Button {
          catalog.update { $0.contentType = type }
        } label: {
          Self.checkmarkLabel(LocalizedStringKey(type.title), selected: catalog.filter.contentType == type)
        }
      }
    }
  }

  private var genreMenu: some View {
    let selected = catalog.genres.first { $0.id == catalog.filter.genreID }
    return Self.menu(label: selected.map { LocalizedStringKey($0.title) } ?? "Genre",
                     icon: "theatermasks",
                     isActive: catalog.filter.genreID != nil) {
      Button {
        catalog.update { $0.genreID = nil }
      } label: {
        Self.checkmarkLabel("Any", selected: catalog.filter.genreID == nil)
      }
      ForEach(catalog.genres) { genre in
        Button {
          catalog.update { $0.genreID = genre.id }
        } label: {
          Self.checkmarkLabel(LocalizedStringKey(genre.title), selected: catalog.filter.genreID == genre.id)
        }
      }
    }
  }

  private var countryMenu: some View {
    let selected = catalog.countries.first { $0.id == catalog.filter.countryID }
    return Self.menu(label: selected.map { LocalizedStringKey($0.title) } ?? "Country",
                     icon: "globe",
                     isActive: catalog.filter.countryID != nil) {
      Button {
        catalog.update { $0.countryID = nil }
      } label: {
        Self.checkmarkLabel("Any", selected: catalog.filter.countryID == nil)
      }
      ForEach(catalog.countries, id: \.id) { country in
        Button {
          catalog.update { $0.countryID = country.id }
        } label: {
          Self.checkmarkLabel(LocalizedStringKey(country.title), selected: catalog.filter.countryID == country.id)
        }
      }
    }
  }

  private var yearMenu: some View {
    Self.menu(label: catalog.filter.years.map { LocalizedStringKey($0.title) } ?? "Years",
              icon: "calendar",
              isActive: catalog.filter.years != nil) {
      Button {
        catalog.update { $0.years = nil }
      } label: {
        Self.checkmarkLabel("Any", selected: catalog.filter.years == nil)
      }
      ForEach(years) { range in
        Button {
          catalog.update { $0.years = range }
        } label: {
          Self.checkmarkLabel(LocalizedStringKey(range.title), selected: catalog.filter.years == range)
        }
      }
    }
  }

  // MARK: - Building blocks

  @ViewBuilder
  static func menu<Content: View>(label: LocalizedStringKey,
                                  icon: String,
                                  isActive: Bool,
                                  @ViewBuilder content: () -> Content) -> some View {
    // Branching on the style rather than erasing it: a wrapper that can hold either
    // concrete style has to conform to the protocol itself, which is more machinery
    // than two short branches.
    if isActive {
      Menu {
        content()
      } label: {
        Label(label, systemImage: icon).lineLimit(1)
      }
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.capsule)
      .tint(Color.KinoPub.accent)
    } else {
      Menu {
        content()
      } label: {
        Label(label, systemImage: icon).lineLimit(1)
      }
      .buttonStyle(.bordered)
      .buttonBorderShape(.capsule)
    }
  }

  /// Menus on tvOS don't mark the selected row themselves.
  static func checkmarkLabel(_ title: LocalizedStringKey, selected: Bool) -> some View {
    Label(title, systemImage: selected ? "checkmark" : "")
  }

#if os(tvOS)
  static let spacing: CGFloat = 16
  static let horizontalInset: CGFloat = 80
  static let verticalPadding: CGFloat = 16
  static let font: Font = .system(size: 24, weight: .semibold)
#else
  static let spacing: CGFloat = 10
  static let horizontalInset: CGFloat = 16
  static let verticalPadding: CGFloat = 8
  static let font: Font = .system(size: 14, weight: .semibold)
#endif
}

/// The sort dropdown on its own. A person's credits are the same listing narrowed to
/// one name, so they get sorting without the filter pickers around it.
struct LibrarySortMenu: View {

  @ObservedObject var catalog: LibraryCatalog

  var body: some View {
    LibraryFiltersBar.menu(label: LocalizedStringKey(catalog.filter.sort.titleKey),
                           icon: "arrow.up.arrow.down",
                           isActive: false) {
      ForEach(MediaSortOrder.allCases) { order in
        Button {
          catalog.update { $0.sort = order }
        } label: {
          LibraryFiltersBar.checkmarkLabel(LocalizedStringKey(order.titleKey),
                                           selected: catalog.filter.sort == order)
        }
      }
    }
  }
}
