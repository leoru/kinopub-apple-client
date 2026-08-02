//
//  RootView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

struct RootView: View {

  @Environment(\.appContext) var appContext
  @EnvironmentObject var authState: AuthState

  var body: some View {
    ZStack {
      // The app is swapped out entirely, not covered: a live catalog behind the code keeps loading
      // artwork and cycling the hero, which flickers through the material — and its requests, all
      // unauthorized, would raise error toasts on top of a screen you cannot leave.
      if authState.shouldShowAuthentication {
        AuthView(model: AuthModel(authService: appContext.authService, authState: authState))
              .transition(.blurReplace)
      } else {
        TabsNavigationView()
      }
    }
    .animation(.default, value: authState.shouldShowAuthentication)
    .task {
      await authState.check()
    }
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
