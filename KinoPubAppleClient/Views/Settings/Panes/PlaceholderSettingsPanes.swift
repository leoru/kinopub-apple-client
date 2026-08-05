//
//  PlaceholderSettingsPanes.swift
//  KinoPubAppleClient
//
//  Demo panes: interactive System Settings–style chrome, @State only (no persistence).
//

import SwiftUI

#if !os(tvOS)

struct DownloadsSettingsPane: View {
  @State private var wifiOnly = true
  @State private var qualityRaw = "1080"
  @State private var deleteAfterWatch = false

  var body: some View {
    Form {
      Section {
        Toggle("Wi‑Fi only", isOn: $wifiOnly)
        Picker("Download quality", selection: $qualityRaw) {
          Text("720p").tag("720")
          Text("1080p").tag("1080")
          Text("4K").tag("4k")
        }
        .pickerStyle(.menu)
        Toggle("Delete after watching", isOn: $deleteAfterWatch)
      } footer: {
        Text("Demo controls — not saved yet.")
      }
    }
    .formStyle(.grouped)
  }
}

struct DevicesSettingsPane: View {
  @State private var preferHEVC = true
  @State private var allow4K = true
  @State private var allowHDR = true
  @State private var mixedPlaylist = false

  var body: some View {
    Form {
      Section {
        Toggle("Prefer HEVC", isOn: $preferHEVC)
        Toggle("Allow 4K", isOn: $allow4K)
        Toggle("Allow HDR", isOn: $allowHDR)
        Toggle("Mixed playlists", isOn: $mixedPlaylist)
      } header: {
        Text("This device")
      } footer: {
        Text("Capabilities already sync on sign-in. These controls are placeholders.")
      }

      Section("Other devices") {
        LabeledContent("Living Room", value: "Apple TV")
        LabeledContent("MacBook", value: "This Mac")
      }
    }
    .formStyle(.grouped)
  }
}

struct AppearanceSettingsPane: View {
  @State private var reduceMotion = false
  @State private var showPosterTitles = true
  @State private var accentRaw = "system"

  var body: some View {
    Form {
      Section {
        LabeledContent("Theme", value: "Dark")
        Toggle("Show titles on posters", isOn: $showPosterTitles)
        Toggle("Reduce motion", isOn: $reduceMotion)
        Picker("Accent", selection: $accentRaw) {
          Text("System").tag("system")
          Text("Blue").tag("blue")
          Text("Orange").tag("orange")
        }
        .pickerStyle(.menu)
      } footer: {
        Text("Dark-only until a deliberate light-theme pass. Demo controls are not saved.")
      }
    }
    .formStyle(.grouped)
  }
}

struct SidebarSettingsPane: View {
  @State private var showFolders = true
  @State private var compactIcons = false

  var body: some View {
    Form {
      Section {
        Toggle("Show bookmark folders", isOn: $showFolders)
        Toggle("Compact sidebar icons", isOn: $compactIcons)
        Text("Customize tabs from the sidebar’s Edit menu when available.")
          .foregroundStyle(.secondary)
          .font(.callout)
      } footer: {
        Text("Demo controls — tab customization already uses system TabViewCustomization.")
      }
    }
    .formStyle(.grouped)
  }
}

struct NotificationsSettingsPane: View {
  @State private var downloadComplete = true
  @State private var newEpisodes = false
  @State private var watchlistReminders = false

  var body: some View {
    Form {
      Section {
        Toggle("Download complete", isOn: $downloadComplete)
        Toggle("New episodes", isOn: $newEpisodes)
        Toggle("Watchlist reminders", isOn: $watchlistReminders)
      } footer: {
        Text("Demo controls — not saved yet.")
      }
    }
    .formStyle(.grouped)
  }
}

struct DetailsSettingsPane: View {
  /// Real and saved, unlike the demo toggles below it.
  @AppStorage(MediaItemDisplayPreferences.showAgeRatingBadgeKey)
  private var showAgeRatingBadge = false

  @State private var showCast = true
  @State private var showAwards = true
  @State private var showSimilar = true
  @State private var showTrailers = true

  var body: some View {
    Form {
      Section {
        Toggle("Age rating badge", isOn: $showAgeRatingBadge)
      } header: {
        Text("Metadata")
      } footer: {
        Text("Shows the certification chip beside the year on a title's hero. The rating is always listed in the information table.")
      }

      Section {
        Toggle("Cast & crew", isOn: $showCast)
        Toggle("Awards", isOn: $showAwards)
        Toggle("Similar titles", isOn: $showSimilar)
        Toggle("Trailers", isOn: $showTrailers)
      } header: {
        Text("Detail sections")
      } footer: {
        Text("Demo controls — not saved yet.")
      }
    }
    .formStyle(.grouped)
  }
}

struct BackupsSettingsPane: View {
  @State private var iCloudSync = false
  @State private var includeWatchHistory = true
  @State private var includeSettings = true

  var body: some View {
    Form {
      Section {
        Toggle("iCloud Sync", isOn: $iCloudSync)
        Toggle("Include watch history", isOn: $includeWatchHistory)
          .disabled(!iCloudSync)
        Toggle("Include settings", isOn: $includeSettings)
          .disabled(!iCloudSync)
      } footer: {
        Text("Aspirational — after local DB foundation. Demo controls are not saved.")
      }
    }
    .formStyle(.grouped)
  }
}

struct NetworkSettingsPane: View {
  @State private var useProxy = false
  @State private var preferIPv6 = false

  var body: some View {
    Form {
      Section {
        LabeledContent("Status", value: "Online")
        Toggle("Use proxy", isOn: $useProxy)
        Toggle("Prefer IPv6", isOn: $preferIPv6)
        Button("Run Speed Test") {}
          .disabled(true)
      } footer: {
        Text("Demo controls — not saved yet.")
      }
    }
    .formStyle(.grouped)
  }
}

#endif
