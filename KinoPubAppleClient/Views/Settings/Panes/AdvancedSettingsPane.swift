//
//  AdvancedSettingsPane.swift
//  KinoPubAppleClient
//

import SwiftUI

#if !os(tvOS)
struct AdvancedSettingsPane: View {
  @State private var verboseLogging = false
  @State private var keepPlaybackDiagnostics = false

  var body: some View {
    Form {
#if DEBUG
      Section("Diagnostics") {
        NavigationLink("Stream survey", value: SettingsDetailRoute.streamSurvey)
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
