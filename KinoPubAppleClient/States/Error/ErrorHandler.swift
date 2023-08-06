//
//  ErrorHandler.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation
import SwiftUI

final class ErrorHandler: ObservableObject {
  
  struct State {
    var error: String?
    var showError: Bool = false
  }
  
  @Published var state: State = State(error: nil, showError: false)
  
  func setError(_ error: Error) {
    self.state = State(error: error.localizedDescription, showError: true)
  }
  
  func reset() {
    self.state = State(error: nil, showError: false)
  }
}

