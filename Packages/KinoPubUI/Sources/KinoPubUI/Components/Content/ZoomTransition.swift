//
//  ZoomTransition.swift
//  KinoPubUI
//

import SwiftUI

private struct ZoomTransitionNamespaceKey: EnvironmentKey {
  static let defaultValue: Namespace.ID? = nil
}

public extension EnvironmentValues {
  var zoomTransitionNamespace: Namespace.ID? {
    get { self[ZoomTransitionNamespaceKey.self] }
    set { self[ZoomTransitionNamespaceKey.self] = newValue }
  }
}

public struct MediaZoomSourceModifier: ViewModifier {
  let id: String
  @Environment(\.zoomTransitionNamespace) private var namespace

  public init(id: String) {
    self.id = id
  }

  public func body(content: Content) -> some View {
#if os(iOS) || os(tvOS)
    if let namespace {
      content.matchedTransitionSource(id: id, in: namespace)
    } else {
      content
    }
#else
    content
#endif
  }
}

public extension View {
  /// Marks artwork as the zoom transition source when the enclosing stack published
  /// a namespace via `\.zoomTransitionNamespace`.
  func mediaZoomSource(id: String) -> some View {
    modifier(MediaZoomSourceModifier(id: id))
  }
}
