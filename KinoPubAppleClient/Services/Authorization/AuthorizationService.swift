//
//  AuthorizationService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import KinoPubBackend

protocol AuthorizationService {
  func fetchDeviceCode() async throws -> VerificationResponse
  func fetchToken(by verification: VerificationResponse) async throws
  func refreshToken() async throws
}

protocol AuthorizationServiceProvider {
  var authService: AuthorizationService { get set }
}
