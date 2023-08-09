//
//  SettingsModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 9.08.2023.
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import OSLog

@MainActor
class ProfileModel: ObservableObject {
  
  private var userService: UserService
  private var errorHandler: ErrorHandler
  private var authState: AuthState
  
  @Published public var userData: UserData = UserData.mock()
  
  init(userService: UserService,
       errorHandler: ErrorHandler,
       authState: AuthState) {
    self.userService = userService
    self.errorHandler = errorHandler
    self.authState = authState
  }
  
  func fetch() {
    Task {
      do {
        self.userData = try await userService.fetchUserData()
      } catch {
        errorHandler.setError(error)
      }
    }
  }
  
  func logout() {
    authState.logout()
  }
}
