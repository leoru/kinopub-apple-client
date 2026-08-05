//
//  AccessTokenServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KinoPubBackend

extension Key where Value: Token {
  static var token: Key { .init(rawValue: "com.kunst.kinopub.token") }
}

#if DEBUG && targetEnvironment(simulator)
/// Dev-loop convenience, Simulator + DEBUG only: mirrors the activated token to a
/// dotfile in the Mac user's home directory — outside the repo, never committed —
/// so reinstalling the app on the same Simulator (a fresh `xcodebuild` / a
/// different destination) doesn't force re-activating on kino.pub every time.
/// Never compiled into a device or Release build.
private enum DevSessionMirror {
  /// `homeDirectoryForCurrentUser` is unavailable on iOS; Simulator sets this env
  /// var on every child process to the real Mac user's home, which is the
  /// standard way an iOS-target binary reaches outside its sandboxed container
  /// while running on Simulator.
  static let fileURL: URL? = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"].map {
    URL(fileURLWithPath: $0).appendingPathComponent(".kinopub-dev-session.json")
  }

  /// `Token: Codable`, so this encodes straight from the generic parameter — no
  /// need to construct an `AccessToken` (its memberwise init isn't public).
  static func save<T: Token>(_ token: T) {
    guard let fileURL, let data = try? JSONEncoder().encode(token) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }

  static func load() -> AccessToken? {
    guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
    return try? JSONDecoder().decode(AccessToken.self, from: data)
  }

  static func delete() {
    guard let fileURL else { return }
    try? FileManager.default.removeItem(at: fileURL)
  }
}
#endif

public final class AccessTokenServiceImpl: AccessTokenService {

  private let storage: KeychainStorage

  init(storage: KeychainStorage) {
    self.storage = storage
  }

  func set<T>(token: T) where T: Token {
    storage.setObject(token, for: .token)
#if DEBUG && targetEnvironment(simulator)
    DevSessionMirror.save(token)
#endif
  }

  func token<T>() -> T? where T: Token {
    if let stored: T = storage.object(for: .token) {
      return stored
    }
#if DEBUG && targetEnvironment(simulator)
    // Keychain came back empty (fresh install/reinstall lost it) — fall back to
    // the mirrored dev session and reseed the real Keychain from it, so this
    // fallback only ever fires once per reinstall.
    if let dev = DevSessionMirror.load(), let seeded = dev as? T {
      storage.setObject(dev, for: .token)
      return seeded
    }
#endif
    return nil
  }

  func clear() {
    storage.clear()
#if DEBUG && targetEnvironment(simulator)
    DevSessionMirror.delete()
#endif
  }

}
