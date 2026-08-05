//
//  PlaceholderSettingsPanes.swift
//  KinoPubAppleClient
//
//  Demo panes: interactive System Settings–style chrome, @State only (no persistence).
//

import SwiftUI
import KinoPubUI

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
  @AppStorage(MediaCardDisplayPreferences.ratingPlacementKey)
  private var ratingPlacement = MediaCardDisplayPreferences.defaultRatingPlacement.rawValue
  @AppStorage(MediaCardDisplayPreferences.ratingSourceKey)
  private var ratingSource = MediaCardDisplayPreferences.defaultRatingSource.rawValue
  @AppStorage(MediaCardDisplayPreferences.capabilityPlacementKey)
  private var capabilityPlacement = MediaCardDisplayPreferences.defaultCapabilityPlacement.rawValue
  @AppStorage(MediaCardDisplayPreferences.show4KKey)
  private var show4K = MediaCardDisplayPreferences.defaultShow4K
  @AppStorage(MediaCardDisplayPreferences.showHDRKey)
  private var showHDR = MediaCardDisplayPreferences.defaultShowHDR
  @AppStorage(MediaCardDisplayPreferences.showHDKey)
  private var showHD = MediaCardDisplayPreferences.defaultShowHD
  @AppStorage(MediaCardDisplayPreferences.show3DKey)
  private var show3D = MediaCardDisplayPreferences.defaultShow3D
  @AppStorage(MediaCardDisplayPreferences.showCCKey)
  private var showCC = MediaCardDisplayPreferences.defaultShowCC
  @AppStorage(MediaCardDisplayPreferences.editorialPlacementKey)
  private var editorialPlacement = MediaCardDisplayPreferences.defaultEditorialPlacement.rawValue
  @AppStorage(MediaCardDisplayPreferences.showOriginalTitleKey)
  private var showOriginalTitle = MediaCardDisplayPreferences.defaultShowOriginalTitle
  @AppStorage(MediaCardDisplayPreferences.showYearKey)
  private var showYear = MediaCardDisplayPreferences.defaultShowYear
  @AppStorage(MediaCardDisplayPreferences.showDurationKey)
  private var showDuration = MediaCardDisplayPreferences.defaultShowDuration
  @AppStorage(MediaCardDisplayPreferences.showGenreKey)
  private var showGenre = MediaCardDisplayPreferences.defaultShowGenre
  @AppStorage(MediaCardDisplayPreferences.showCountryKey)
  private var showCountry = MediaCardDisplayPreferences.defaultShowCountry
  @AppStorage(MediaCardDisplayPreferences.showBookmarkSymbolKey)
  private var showBookmarkSymbol = MediaCardDisplayPreferences.defaultShowBookmarkSymbol
  @AppStorage(MediaCardDisplayPreferences.progressVisibilityKey)
  private var progressVisibility = MediaCardDisplayPreferences.defaultProgressVisibility.rawValue
  @AppStorage(MediaCardDisplayPreferences.watchedStyleKey)
  private var watchedStyle = MediaCardDisplayPreferences.defaultWatchedStyle.rawValue

  var body: some View {
    Form {
      Section {
        LabeledContent("Theme", value: "Dark")
      } footer: {
        Text("Dark-only until a deliberate light-theme pass.")
      }

      Section {
        Picker("Rating", selection: $ratingPlacement) {
          ForEach(MediaCardChromePlacement.allCases) { placement in
            Text(LocalizedStringKey(placement.titleKey)).tag(placement.rawValue)
          }
        }
        Picker("Rating source", selection: $ratingSource) {
          ForEach(MediaCardRatingSource.allCases) { source in
            Text(LocalizedStringKey(source.titleKey)).tag(source.rawValue)
          }
        }
        .disabled(ratingPlacement == MediaCardChromePlacement.hidden.rawValue)
      } header: {
        Text("Poster score")
      } footer: {
        Text("On poster uses the coloured plaque. Under title shows IMDb / Kinopoisk logos separately.")
      }

      Section {
        Picker("Quality badges", selection: $capabilityPlacement) {
          ForEach(MediaCardChromePlacement.allCases) { placement in
            Text(LocalizedStringKey(placement.titleKey)).tag(placement.rawValue)
          }
        }
        Toggle("4K", isOn: $show4K)
        Toggle("HDR", isOn: $showHDR)
        Toggle("HD", isOn: $showHD)
        Toggle("3D", isOn: $show3D)
        Toggle("CC", isOn: $showCC)
        Picker("New-episode badge", selection: $editorialPlacement) {
          ForEach(MediaCardChromePlacement.allCases) { placement in
            Text(LocalizedStringKey(placement.titleKey)).tag(placement.rawValue)
          }
        }
        Toggle("Bookmark on artwork", isOn: $showBookmarkSymbol)
      } header: {
        Text("Badges")
      } footer: {
        Text("Bookmark sits top-trailing, right of the quality chips.")
      }

      Section {
        Toggle("Original title", isOn: $showOriginalTitle)
        Toggle("Year", isOn: $showYear)
        Toggle("Genre", isOn: $showGenre)
        Toggle("Country", isOn: $showCountry)
      } header: {
        Text("Vertical posters")
      } footer: {
        Text("Original title never appears under landscape Continue Watching cards.")
      }

      Section {
        Toggle("Duration chip", isOn: $showDuration)
        Picker("Progress bar", selection: $progressVisibility) {
          ForEach(MediaCardProgressVisibility.allCases) { visibility in
            Text(LocalizedStringKey(visibility.titleKey)).tag(visibility.rawValue)
          }
        }
        Picker("Watched", selection: $watchedStyle) {
          ForEach(MediaCardWatchedStyle.allCases) { style in
            Text(LocalizedStringKey(style.titleKey)).tag(style.rawValue)
          }
        }
      } header: {
        Text("Landscape cards")
      } footer: {
        Text("Duration chip pins bottom-leading. New-episode counts (+N) render as a caption label, not a title chip. Watched dim/checkmark is for vertical posters.")
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
