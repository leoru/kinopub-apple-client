//
//  SectionVisibilityStore.swift
//  KinoPubAppleClient
//
//  Persisted show/hide for the optional tabs — plain `UserDefaults`, not the system
//  `TabViewCustomization` that `TabsNavigationView` already uses for macOS sidebar
//  reordering. `TabViewCustomization` is `@available(tvOS, unavailable)` (see
//  .claude/skills/apple-chrome/SKILL.md), so a store meant to apply on every
//  platform, tvOS included, has to carry its own state instead of leaning on it.
//
//  NOTE: this only *stores* visibility today. Actually hiding a section in
//  `TabsNavigationView`'s tab-building switch is deliberately left to the follow-up
//  catalog-sections work (docs/archive/plans/community-parity-port.md §3/§8) — that file is
//  also where the new sections land, and editing the same switch from two directions at
//  once is exactly the collision that split is meant to avoid.
//

import Foundation
import SwiftUI

/// One optional section a user can hide from their tab bar / sidebar.
struct AppSection: Identifiable {
  let id: String
  let titleKey: LocalizedStringKey
}

final class SectionVisibilityStore: ObservableObject {
  static let shared = SectionVisibilityStore()

  private let defaultsKey = "hiddenSectionIDs"
  @Published private(set) var hiddenIDs: Set<String>

  private init() {
    hiddenIDs = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
  }

  /// Movies and Series are the two tabs every other section hangs off of — can't be hidden.
  static let forcedVisibleIDs: Set<String> = ["movies", "series"]

  /// Sections grouped the way the toggle screen presents them, seeded from the tabs that
  /// actually exist today in `TabsNavigationView` / `NavigationTabs`.
  static let librarySections: [AppSection] = {
    var items = [
      AppSection(id: "movies", titleKey: "Movies"),
      AppSection(id: "series", titleKey: "Series"),
      AppSection(id: "watchlist", titleKey: "Watchlist"),
      AppSection(id: "history", titleKey: "History")
    ]
    if FeatureFlags.allBookmarksEnabled {
      items.append(AppSection(id: "bookmarks", titleKey: "All Bookmarks"))
    }
    return items
  }()

  static let otherSections: [AppSection] = {
    guard FeatureFlags.downloadsEnabled else { return [] }
    return [AppSection(id: "downloads", titleKey: "Downloads")]
  }()

  func canHide(_ section: AppSection) -> Bool { !Self.forcedVisibleIDs.contains(section.id) }

  func isVisible(_ section: AppSection) -> Bool { !hiddenIDs.contains(section.id) }

  func setVisible(_ visible: Bool, for section: AppSection) {
    guard canHide(section) else { return }
    if visible {
      hiddenIDs.remove(section.id)
    } else {
      hiddenIDs.insert(section.id)
    }
    UserDefaults.standard.set(Array(hiddenIDs), forKey: defaultsKey)
  }
}
