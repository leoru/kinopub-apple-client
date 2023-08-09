//
//  KeychainStorageImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KeychainAccess

final class KeychainStorageImpl: KeychainStorage {

  private lazy var keychain: Keychain = {
    return Keychain(service: "com.kunst.kinopub")
  }()

  public func object<Value>(for key: Key<Value>) -> Value? where Value: Decodable, Value: Encodable {
    do {
      guard let data = try keychain.getData(key.rawValue) else { return nil }
      return try JSONDecoder().decode(Value.self, from: data)
    } catch {
      print(error)
      return nil
    }
  }

  public func setObject<Value>(_ object: Value?, for key: Key<Value>) where Value: Decodable, Value: Encodable {
    do {
      let data = try JSONEncoder().encode(object)
      try keychain.set(data, key: key.rawValue)
    } catch {
      print(error)
    }
  }
  
  func clear() {
    do {
      try keychain.removeAll()
    } catch {
      print(error)
    }
  }
}
