//
//  SettingsCategory.swift
//  KinoPubAppleClient
//

import SwiftUI

/// Shared settings catalog for macOS (sidebar) and iOS (list). tvOS keeps its own chrome.
enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
  case general
  case playback
  case integrations
  case downloads
  case devices
  case appearance
  case sidebar
  case notifications
  case details
  case backups
  case network
  case advanced

  var id: String { rawValue }

  var titleKey: LocalizedStringKey {
    switch self {
    case .general: return "General"
    case .playback: return "Playback"
    case .integrations: return "Integrations"
    case .downloads: return "Downloads"
    case .devices: return "Devices"
    case .appearance: return "Appearance"
    case .sidebar: return "Sidebar"
    case .notifications: return "Notifications"
    case .details: return "Details"
    case .backups: return "Backups"
    case .network: return "Network"
    case .advanced: return "Advanced"
    }
  }

  var systemImage: String {
    switch self {
    case .general: return "gearshape.fill"
    case .playback: return "play.rectangle.fill"
    case .integrations: return "puzzlepiece.extension.fill"
    case .downloads: return "arrow.down.circle.fill"
    case .devices: return "laptopcomputer.and.iphone"
    case .appearance: return "paintbrush.fill"
    case .sidebar: return "sidebar.left"
    case .notifications: return "bell.badge.fill"
    case .details: return "doc.text.magnifyingglass"
    case .backups: return "externaldrive.fill.badge.icloud"
    case .network: return "network"
    case .advanced: return "wrench.and.screwdriver.fill"
    }
  }

  /// Fill for the rounded Settings icon tile (Apple-style colored squares).
  var iconColor: Color {
    switch self {
    case .general:
      return Color(red: 0.56, green: 0.56, blue: 0.58)
    case .playback:
      return Color(red: 0.20, green: 0.48, blue: 0.96)
    case .integrations:
      return Color(red: 0.56, green: 0.35, blue: 0.90)
    case .downloads:
      return Color(red: 0.18, green: 0.55, blue: 0.95)
    case .devices:
      return Color(red: 0.25, green: 0.52, blue: 0.95)
    case .appearance:
      return Color(red: 0.35, green: 0.55, blue: 0.98)
    case .sidebar:
      return Color(red: 0.45, green: 0.50, blue: 0.58)
    case .notifications:
      return Color(red: 0.95, green: 0.28, blue: 0.30)
    case .details:
      return Color(red: 0.95, green: 0.55, blue: 0.15)
    case .backups:
      return Color(red: 0.25, green: 0.70, blue: 0.85)
    case .network:
      return Color(red: 0.20, green: 0.48, blue: 0.96)
    case .advanced:
      return Color(red: 0.45, green: 0.45, blue: 0.48)
    }
  }

  /// Whether this row appears in the catalog on the current platform / flags.
  var isAvailable: Bool {
    switch self {
    case .downloads:
#if os(tvOS)
      return false
#else
      return FeatureFlags.downloadsEnabled
#endif
    case .sidebar:
#if os(macOS)
      return true
#else
      return false
#endif
    default:
      return true
    }
  }

  static var availableCategories: [SettingsCategory] {
    allCases.filter(\.isAvailable)
  }
}
