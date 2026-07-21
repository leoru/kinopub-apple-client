//
//  EnvironmentValues+CardFocused.swift
//
//

import SwiftUI

private struct CardFocusedKey: EnvironmentKey {
  static let defaultValue = false
}

public extension EnvironmentValues {
  /// Whether the card's enclosing button is focused. Set by the card button styles
  /// and read by `MediaCardView`, because a label subtree cannot rely on reading
  /// `\.isFocused` directly — only the focusable button sees it.
  var cardFocused: Bool {
    get { self[CardFocusedKey.self] }
    set { self[CardFocusedKey.self] = newValue }
  }
}
