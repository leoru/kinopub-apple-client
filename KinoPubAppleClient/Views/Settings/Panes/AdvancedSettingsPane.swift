//
//  AdvancedSettingsPane.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI

#if !os(tvOS)
struct AdvancedSettingsPane: View {
  @AppStorage(DiagnosticsSettings.activityOverlayKey) private var showsActivityOverlay = false
  @AppStorage(DiagnosticsSettings.remoteLoggingKey) private var streamsToPulse = false
#if DEBUG && os(macOS)
  @Environment(\.openWindow) private var openWindow
#endif

  var body: some View {
    Form {
      Section {
        NavigationLink("Storage", value: SettingsDetailRoute.storage)
      }

      Section {
        NavigationLink("Network log", value: SettingsDetailRoute.networkLog)
        Toggle("Show in-flight requests", isOn: $showsActivityOverlay)
        Toggle("Stream to Pulse on Mac", isOn: $streamsToPulse)
#if DEBUG
        NavigationLink("Stream survey", value: SettingsDetailRoute.streamSurvey)
        NavigationLink("Type Styles", value: SettingsDetailRoute.typeStyles)
#endif
      } header: {
        Text("Diagnostics")
      } footer: {
        Text("The log keeps every request with its headers, body and timing for 14 days on this device. Nothing leaves the device unless you switch on streaming; tokens are redacted before they are written either way. Streaming finds the Pulse app on the same network and connects to it — the first time, the system will ask for local network access.")
      }
      .onChange(of: streamsToPulse) { _, isOn in
        NetworkDiagnostics.setRemoteLoggingEnabled(isOn)
      }

#if DEBUG
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
        NavigationLink("UI Lab — Library Sidebar", value: SettingsDetailRoute.libraryLab)
      } header: {
        Text("UI Lab")
      } footer: {
        Text("DEBUG only. Navigation Split is the current candidate. On Search, switch Filter axis: Accessory Chips (Photos-style glass row under the field) vs Toolbar Menus (Settings-style scope + icon menus).")
      }
#endif
    }
    .formStyle(.grouped)
  }
}
#endif
