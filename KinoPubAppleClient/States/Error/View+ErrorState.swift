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
  
  /// Displays a popup with an error message when the error state is true.
  /// - Parameter state: A binding to the error state.
  /// - Returns: A modified view with error handling.
  func handleError(state: Binding<ErrorHandler.State>) -> some View {
    self.popup(isPresented: state.showError) {
      ToastContentView(text: state.error.wrappedValue ?? "")
        .padding()
    } customize: {
      $0
        .type(.floater())
        .position(.bottom)
        .animation(.spring())
        .closeOnTapOutside(true)
        .autohideIn(5.0)
    }
  }
  
}
