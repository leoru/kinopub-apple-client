//
//  KinopoiskKeyStorage.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubMetadata

/// Separate Keychain service from `"com.kunst.kinopub"` — this key isn't
/// kino.pub-session-scoped, so `KeychainStorageImpl.clear()` on logout must not
/// wipe it. See the isolated-storage note in the Kinopoisk integration plan.
private let kinopoiskKeychainService = "com.kunst.kinopub.kinopoisk"

extension Key where Value == String {
  static var kinopoiskAPIKey: Key<String> { .init(rawValue: "apiKey") }
}

/// Not a secret — just "has the currently stored key passed a validation call."
/// Plain UserDefaults, cleared whenever the key text changes.
enum KinopoiskKeyValidation {
  private static let defaultsKey = "kinopoiskAPIKeyValidated"

  static var isValidated: Bool {
    get { UserDefaults.standard.bool(forKey: defaultsKey) }
    set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
  }
}

/// Bridges the isolated Kinopoisk Keychain storage to `KinopoiskKeyProviding`.
/// `currentAPIKey()` (the protocol method `KinopoiskSource` calls) only returns a
/// key once it's validated, so a typo'd key doesn't get hit on every detail-page
/// load — Settings goes through `rawKey()`/`save(key:)`/`markValidated()` instead,
/// which need the unvalidated value too (to prefill the field, to know what to
/// validate).
final class KinopoiskKeyProvider: KinopoiskKeyProviding, @unchecked Sendable {
  private let storage: KeychainStorage

  init(storage: KeychainStorage = KeychainStorageImpl(service: kinopoiskKeychainService)) {
    self.storage = storage
  }

  func currentAPIKey() -> String? {
    guard KinopoiskKeyValidation.isValidated else { return nil }
    let key: String? = storage.object(for: .kinopoiskAPIKey)
    return (key?.isEmpty ?? true) ? nil : key
  }

  func rawKey() -> String? {
    storage.object(for: .kinopoiskAPIKey)
  }

  func save(key: String?) {
    storage.setObject(key, for: .kinopoiskAPIKey)
    KinopoiskKeyValidation.isValidated = false
  }

  func markValidated() {
    KinopoiskKeyValidation.isValidated = true
  }
}
