//
//  RouteStack.swift
//  KinoPubAppleClient
//
//  One place where a tab's stack, its path, and the destination registry meet.
//
//  Before this file, ten screens each wrote the same four lines — a `NavigationStack`
//  bound to one of `NavigationState`'s arrays, a `.navigationDestination(for: Route.self)`
//  building a `RouteDestination`, and a `.navigationStackActive` gate — and they had
//  already drifted: two passed a zoom namespace, eight didn't, and only some carried the
//  gate. A destination registry that exists in ten copies is the catalogue rule being
//  broken at the navigation layer (.claude/skills/tvos-surface/SKILL.md).
//

import SwiftUI

/// A tab's whole navigation surface: the stack, the path it is bound to, the shared
/// destination registry, and the "only the selected tab exposes a stack" gate.
///
/// `zoom` is opt-in per stack, not a default, because the zoom source modifier is
/// `#if os(iOS)`-only (`KinoPubUI.MediaZoomSourceModifier`) and publishing a namespace
/// on a stack whose cards never mark a source gives the destination a transition with
/// nothing to match. Home and the catalog tabs publish one; the rest deliberately do not.
struct RouteStack<Content: View>: View {

  let tab: NavigationTabs
  var zoom: Bool = false
  @ViewBuilder var content: () -> Content

  @EnvironmentObject private var navigationState: NavigationState
  @Namespace private var zoomNamespace

  var body: some View {
    NavigationStack(path: navigationState.path(for: tab)) {
      content()
        .appRouteDestinations(zoom: zoom ? zoomNamespace : nil)
    }
    .environment(\.zoomTransitionNamespace, zoom ? zoomNamespace : nil)
    .navigationStackActive(for: tab, selected: navigationState.selectedTab)
  }
}

extension View {
  /// The app's single `Route` destination registry.
  ///
  /// Use this directly only on a stack `RouteStack` cannot own — one whose path is local
  /// `@State` rather than a tab's shared array (bookmark-folder tabs, tvOS Settings).
  /// Everything else should be a `RouteStack`.
  func appRouteDestinations(zoom namespace: Namespace.ID? = nil) -> some View {
    navigationDestination(for: Route.self) { route in
      RouteDestination(route: route,
                       linkProvider: AppRoutesLinkProvider(),
                       transitionNamespace: namespace)
    }
  }
}
