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
  func fetchToken(by verification: VerificationResponse) async throws -> TokenResponse
  func refreshToken() async throws -> TokenResponse
}
