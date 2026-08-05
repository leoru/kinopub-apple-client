//
//  ErrorHandler.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

/// ErrorHandler is a class that handles error states and provides methods to set and reset errors.
@Observable
final class ErrorHandler {

  /// State is a struct that holds the error message and a flag to indicate whether to show the error.
  struct State {
    var error: String?
    var showError: Bool = false
  }

  /// The current state of the ErrorHandler.
  var state: State = State(error: nil, showError: false)

  /// Sets the error state with the provided error. Cancelled requests are superseded
  /// by newer ones, not failed — they never raise the toast.
  /// - Parameter error: The error to be set.
  func setError(_ error: Error) {
    if let apiError = error as? APIClientError {
      guard !apiError.isCancellation else { return }
      self.state = State(error: apiError.userFacingMessage, showError: true)
    } else {
      self.state = State(error: error.localizedDescription, showError: true)
    }
  }

  /// Resets the error state.
  func reset() {
    self.state = State(error: nil, showError: false)
  }
}
