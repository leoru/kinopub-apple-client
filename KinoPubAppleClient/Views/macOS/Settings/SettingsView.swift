//
//  SettingsView.swift
//  KinoPubAppleClient
//
//  macOS Settings window content — shared catalog lives in SettingsRootView.
//

import SwiftUI

#if os(macOS)
struct SettingsView: View {
  @Environment(\.appContext) private var appContext
  @Environment(ErrorHandler.self) private var errorHandler
  @EnvironmentObject private var authState: AuthState

  var body: some View {
    SettingsSceneHost(
      model: ProfileModel(
        userService: appContext.userService,
        errorHandler: errorHandler,
        authState: authState
      )
    )
  }
}

private struct SettingsSceneHost: View {
  // Eager, not lazy — see the note on `ProfileView.init` in ProfileView.swift and
  // "Observation model" in ROADMAP.md.
  @State private var model: ProfileModel

  init(model: ProfileModel) {
    _model = State(wrappedValue: model)
  }

  var body: some View {
    SettingsRootView(model: model)
  }
}
#endif
