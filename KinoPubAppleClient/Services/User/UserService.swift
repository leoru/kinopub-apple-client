//
//  UserService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 9.08.2023.
//

import Foundation
import KinoPubBackend

protocol UserService {
  func fetchUserData() async throws -> UserData
}

protocol UserServiceProvider {
  var userService: UserService { get set }
}

struct UserServiceMock: UserService {
  func fetchUserData() async throws -> UserData {
    return UserData.mock()
  }
}
