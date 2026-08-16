//
//  RootView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubLogging

struct RootView: View {

  @Environment(\.appContext) var appContext
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var navigationState: NavigationState
  /// Off unless switched on in Settings › Advanced › Diagnostics.
  @AppStorage(DiagnosticsSettings.activityOverlayKey) private var showsActivityOverlay = false
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
      // Above everything, including the blank `.resolving` splash — that splash is
      // exactly the screen whose "what is it waiting for" was unanswerable.
      .networkActivityOverlay(isEnabled: showsActivityOverlay)
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
        VStack(spacing: 16) {
          ProgressView()
          LaunchStatusLabel()
        }
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

/// What the launch is waiting for, in words, instead of a bare spinner.
///
/// The empty loader was the complaint: it says "something is happening" when the
/// interesting question is *what*, and the wait is not one thing but several at once. So
/// this renders **everything** currently outstanding — "Проверяем сессию · Загружаем
/// историю" — because a single-line "Loading…" is the empty spinner with extra steps.
///
/// It reads `NetworkActivity`, which is fed once inside `URLSessionImpl`, so nothing
/// registers by hand, the label cannot fall out of step with the traffic it describes,
/// and a new endpoint shows up here without anyone wiring it.
///
/// Ships in release. Product decision, 2026-08-16.
struct LaunchStatusLabel: View {
  @StateObject private var activity = NetworkActivity.shared

  var body: some View {
    Text(joined)
      .font(TypeScale.cardMeta)
      .foregroundStyle(Color.KinoPub.subtitle)
      .multilineTextAlignment(.center)
      .lineLimit(2)
      .padding(.horizontal, 32)
      // No flicker when one request settles a frame before the next starts, and no
      // layout jump between "nothing registered yet" and the first name.
      .opacity(joined.isEmpty ? 0 : 1)
      .animation(.easeOut(duration: 0.2), value: joined)
  }

  /// Distinct, in the order they started. Three catalogue pages in flight are one thing
  /// the user is waiting for, not three — repeating the name would read as a stutter.
  private var joined: String {
    var seen = Set<String>()
    return activity.inFlight
      .compactMap { seen.insert($0.nameKey).inserted ? $0.nameKey : nil }
      .map { NSLocalizedString($0, comment: "Launch status: what the app is waiting for") }
      .joined(separator: " · ")
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}

#Preview("Launch status") {
  ZStack {
    Color.KinoPub.background.ignoresSafeArea()
    VStack(spacing: 16) {
      ProgressView()
      LaunchStatusLabel()
    }
  }
  .task {
    _ = NetworkActivity.begin(nameKey: "Activity_Session", detail: "/v1/user")
    _ = NetworkActivity.begin(nameKey: "Activity_History", detail: "/v1/history")
  }
  .preferredColorScheme(.dark)
}
