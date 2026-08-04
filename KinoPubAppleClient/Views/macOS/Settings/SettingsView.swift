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
  @EnvironmentObject private var errorHandler: ErrorHandler
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
  @StateObject private var model: ProfileModel

  init(model: @autoclosure @escaping () -> ProfileModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    SettingsRootView(model: model)
  }
}
#endif
