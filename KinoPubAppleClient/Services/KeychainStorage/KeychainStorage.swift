//
//  KeychainStorage.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation

protocol KeyRepresentable {
  var rawValue: String { get }
}

struct Key<Value>: KeyRepresentable {
  public let rawValue: String
  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

protocol KeychainStorage {
  func object<Value>(for key: Key<Value>) -> Value? where Value: Codable
  func setObject<Value>(_ object: Value?, for key: Key<Value>) where Value: Codable
  func clear()
}

protocol KeychainStorageProvider {
  var keychainStorage: KeychainStorage { get set }
}
