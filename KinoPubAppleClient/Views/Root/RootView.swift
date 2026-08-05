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
  @EnvironmentObject var navigationState: NavigationState
#if os(macOS)
  @Environment(\.openWindow) private var openWindow
#endif

  var body: some View {
    // `.resolving` is a blank splash on purpose: mounting Tabs with a Keychain token that
    // then fails refresh is what used to DDoS `/v1/items/*` + spam 401→refresh.
    //
    // iOS/tvOS still swap Auth↔Tabs entirely — a live catalog behind the code used to
    // keep loading artwork, and UIKit's TabView asserts when tabs are removed mid-update.
    //
    // macOS keeps the tab shell mounted and presents Auth as a non-dismissible sheet so
    // the window chrome does not jump from a title-less auth layout into the library.
    rootContent
      .task {
        await authState.check()
      }
#if os(macOS)
      .sheet(isPresented: macAuthSheetPresented) {
        AuthView(model: AuthModel(authService: appContext.authService, authState: authState))
          .frame(minWidth: 440, idealWidth: 520, minHeight: 360, idealHeight: 400)
          .interactiveDismissDisabled()
      }
      .onChange(of: navigationState.playerWindowRequestID) { _, requestID in
        guard requestID != nil else { return }
        openWindow(id: PlaybackWindowState.windowID)
      }
#endif
  }

  @ViewBuilder
  private var rootContent: some View {
    switch authState.phase {
    case .resolving:
      ZStack {
        Color.KinoPub.background.ignoresSafeArea()
        ProgressView()
      }
#if os(macOS)
    case .signedOut, .signedIn:
      TabsNavigationView()
#else
    case .signedOut:
      AuthView(model: AuthModel(authService: appContext.authService, authState: authState))
    case .signedIn:
      TabsNavigationView()
#endif
    }
  }

#if os(macOS)
  /// Sheet stays up for the whole signed-out phase; dismiss is auth success only.
  private var macAuthSheetPresented: Binding<Bool> {
    Binding(
      get: { authState.phase == .signedOut },
      set: { _ in }
    )
  }
#endif
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
