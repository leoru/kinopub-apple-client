//
//  IntegrationsSettingsPane.swift
//  KinoPubAppleClient
//

import SwiftUI

#if !os(tvOS)
struct IntegrationsSettingsPane: View {
  let keyProvider: KinopoiskKeyProvider
  @State private var tmdbEnabled = true
  @State private var futureSourceEnabled = false

  var body: some View {
    Form {
      KinopoiskSettingsSection(keyProvider: keyProvider)

      Section {
        DataSourcesAttributionView()
      } header: {
        Text("Data sources")
      }

      Section {
        Toggle("TMDB enrichment", isOn: $tmdbEnabled)
        Toggle("Additional metadata providers", isOn: $futureSourceEnabled)
      } header: {
        Text("Future sources")
      } footer: {
        Text("Demo controls — not saved yet.")
      }
    }
    .formStyle(.grouped)
  }
}
#endif
