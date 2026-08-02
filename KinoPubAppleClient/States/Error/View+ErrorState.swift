//
//  View+ErrorState.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation
import SwiftUI
import PopupView
import KinoPubUI

/// Extension for the View protocol to handle error states.
extension View {

  /// Shows a transient bottom toast with the error message. Used for failures that
  /// leave content on screen (a pagination page, an action) — a screen with nothing
  /// to show uses `UnavailableView` instead.
  /// - Parameter state: A binding to the error state.
  /// - Returns: A modified view with error handling.
  func handleError(state: Binding<ErrorHandler.State>) -> some View {
    self.popup(isPresented: state.showError) {
      HStack(spacing: 10) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.secondary)
        Text(state.wrappedValue.error ?? "")
          .font(.callout)
          .lineLimit(2)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .background(.regularMaterial, in: Capsule())
      .padding(.bottom, 30)
    } customize: {
      $0
        .type(.floater())
        .position(.bottom)
        .animation(.spring())
        .closeOnTapOutside(true)
        .autohideIn(5.0)
    }
#if os(iOS)
    // The haptic belongs to the error surfacing, not to any view component —
    // it fires once when the toast appears, only on platforms that have haptics.
    .sensoryFeedback(.error, trigger: state.wrappedValue.showError) { _, shown in shown }
#endif
  }

}
