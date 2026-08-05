//
//  TVUIKitPosterEnvironment.swift
//  KinoPubUI
//
//  Gates native TVUIKit posters (shelves + grids share one atom) and provides a
//  NavigationStack-friendly open handler for UIKit selection.
//

import SwiftUI

private struct UsesTVUIKitPostersKey: EnvironmentKey {
  static let defaultValue = false
}

private struct MediaNavigationKey: EnvironmentKey {
  static let defaultValue: ((any Hashable) -> Void)? = nil
}

extension EnvironmentValues {
  /// When true on tvOS, shelves and grids render `TVPosterView` / `TVCardView`
  /// cells instead of SwiftUI `MediaCardView`.
  public var usesTVUIKitPosters: Bool {
    get { self[UsesTVUIKitPostersKey.self] }
    set { self[UsesTVUIKitPostersKey.self] = newValue }
  }

  /// Opens a `navigationDestination` value from a UIKit poster selection.
  public var mediaNavigation: ((any Hashable) -> Void)? {
    get { self[MediaNavigationKey.self] }
    set { self[MediaNavigationKey.self] = newValue }
  }
}
