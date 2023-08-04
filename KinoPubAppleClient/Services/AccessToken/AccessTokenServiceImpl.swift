//
//  AccessTokenServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation

extension Key where Value: Token {
  static var token: Key { .init(rawValue: "com.kunst.kinopub.token") }
}

public final class AccessTokenServiceImpl: AccessTokenService {

  private let storage: KeychainStorage

  init(storage: KeychainStorage) {
    self.storage = storage
  }

  func set<T>(token: T) where T: Token {
    storage.setObject(token, for: .token)
  }

  func token<T>() -> T? where T: Token {
    storage.object(for: .token)
  }

}
