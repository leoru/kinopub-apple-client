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

extension View {
  
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
