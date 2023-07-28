//
//  AuthModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

@MainActor
class AuthModel: ObservableObject {
  
  private var authService: AuthorizationService
  
  @Published var deviceCode: String = ""
  @Published var error: String?
  @Published var showError: Bool = false
  @Published var close: Bool = false
  
  private var tempVerificationResponse: VerificationResponse?
  
  init(authService: AuthorizationService) {
    self.authService = authService
  }
  
  func fetchDeviceCode() {
    error = nil
    showError = false
    Task {
      do {
        let response = try await authService.fetchDeviceCode()
        self.deviceCode = response.userCode
        self.tempVerificationResponse = response
        scheduleCheck(for: response)
      } catch {
        handleError(error)
      }
    }
  }
  
  func openActivationURL() {
    guard let urlString = tempVerificationResponse?.verificationUri, let url = URL(string: urlString) else {
      return
    }
    
    #if os(iOS)
    UIApplication.shared.open(url)
    #endif
  }
  
  private func requestToken(by response: VerificationResponse) async throws {
    do {
      try await authService.fetchToken(by: response)
      close = true
    } catch {
      handleError(error, response: response)
    }
  }
  
  private func scheduleCheck(for response: VerificationResponse) {
    let timeout = UInt64(response.interval)
    Task {
      try await Task.sleep(nanoseconds: timeout * 1_000_000_000)
      try await requestToken(by: response)
    }
  }
  
  private func handleError(_ error: Error, response: VerificationResponse? = nil) {
    guard let error = error as? APIClientError else {
      return
    }
    
    if let response, error.isAuthorizationPending {
      scheduleCheck(for: response)
      return
    }
    
    self.error = error.description
    self.showError = true
  }
  
}

