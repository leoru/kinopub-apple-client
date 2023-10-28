//
//  ErrorHandler.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation
import SwiftUI

/// ErrorHandler is a class that handles error states and provides methods to set and reset errors.
final class ErrorHandler: ObservableObject {
  
  /// State is a struct that holds the error message and a flag to indicate whether to show the error.
  struct State {
    var error: String?
    var showError: Bool = false
  }
  
  /// The current state of the ErrorHandler.
  @Published var state: State = State(error: nil, showError: false)
  
  /// Sets the error state with the provided error.
  /// - Parameter error: The error to be set.
  func setError(_ error: Error) {
    self.state = State(error: error.localizedDescription, showError: true)
  }
  
  /// Resets the error state.
  func reset() {
    self.state = State(error: nil, showError: false)
  }
}
