//
//  AdvancedSettingsPane.swift
//  KinoPubAppleClient
//

import SwiftUI

#if !os(tvOS)
struct AdvancedSettingsPane: View {
  @State private var verboseLogging = false
  @State private var keepPlaybackDiagnostics = false
#if DEBUG && os(macOS)
  @Environment(\.openWindow) private var openWindow
#endif

  var body: some View {
    Form {
#if DEBUG
      Section("Diagnostics") {
        NavigationLink("Stream survey", value: SettingsDetailRoute.streamSurvey)
        NavigationLink("Type Styles", value: SettingsDetailRoute.typeStyles)
      }

      Section {
#if os(macOS)
        Button("UI Lab — Adaptable Sidebar") {
          openWindow(id: UILabWindow.id, value: UILabChrome.adaptableSidebar)
        }
        Button("UI Lab — Navigation Split") {
          openWindow(id: UILabWindow.id, value: UILabChrome.navigationSplit)
        }
#else
        NavigationLink("UI Lab — Adaptable Sidebar", value: SettingsDetailRoute.uiLab(.adaptableSidebar))
        NavigationLink("UI Lab — Navigation Split", value: SettingsDetailRoute.uiLab(.navigationSplit))
#endif
      } header: {
        Text("UI Lab")
      } footer: {
        Text("DEBUG only. Navigation Split is the current candidate. On Search, switch Filter axis: Accessory Chips (Photos-style glass row under the field) vs Toolbar Menus (Settings-style scope + icon menus).")
      }
#endif

      Section {
        Toggle("Verbose logging", isOn: $verboseLogging)
        Toggle("Keep playback diagnostics", isOn: $keepPlaybackDiagnostics)
      } header: {
        Text("Debug")
      } footer: {
        Text("Demo controls — not saved yet.")
      }
    }
    .formStyle(.grouped)
  }
}
#endif
