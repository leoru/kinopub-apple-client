//
//  AccessTokenServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KinoPubBackend

extension Key where Value: Token {
  static var token: Key { .init(rawValue: "com.soda.kinopub.token") }
}

#if DEBUG && (targetEnvironment(simulator) || os(macOS))
/// Dev-loop convenience, DEBUG only: mirrors the activated token to **one** dotfile in
/// the Mac user's home — `~/.kinopub-dev-session.json`, outside the repo, never
/// committed. Every debug build reads and writes that same file, so the macOS app, the
/// tvOS Simulator and the iOS Simulator share a single kino.pub session instead of
/// burning a device slot each (the account has five) and asking for a new activation
/// code after every reinstall or DerivedData wipe.
///
/// Never compiled into a device or Release build.
enum DevSessionMirror {
  private static let fileName = ".kinopub-dev-session.json"

  /// Both branches must resolve the **real** Mac home, not a sandbox container, or the
  /// platforms stop sharing a file and the whole point is lost.
  static let fileURL: URL? = {
#if targetEnvironment(simulator)
    // `homeDirectoryForCurrentUser` is unavailable on iOS/tvOS; Simulator sets this env
    // var on every child process to the real Mac user's home, which is the standard way
    // a simulator binary reaches outside its container.
    ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"].map {
      URL(fileURLWithPath: $0).appendingPathComponent(fileName)
    }
#else
    // Debug macOS runs unsandboxed (`KinoPubAppleClient-Debug.entitlements`), so this is
    // already the real home. Asking the password database anyway costs nothing and keeps
    // the path correct if the sandbox is ever turned back on for Debug.
    guard let pw = getpwuid(getuid())?.pointee.pw_dir else { return nil }
    return URL(fileURLWithPath: String(cString: pw)).appendingPathComponent(fileName)
#endif
  }()

  static var exists: Bool {
    guard let fileURL else { return false }
    return FileManager.default.fileExists(atPath: fileURL.path)
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
#if DEBUG && (targetEnvironment(simulator) || os(macOS))
    DevSessionMirror.save(token)
#endif
  }

  func token<T>() -> T? where T: Token {
    if let stored: T = storage.object(for: .token) {
#if DEBUG && (targetEnvironment(simulator) || os(macOS))
      // Seed the shared file from an already-activated Keychain. Without this the
      // mirror only fills on the *next* activation or refresh, so the first build to
      // adopt it would still burn a device slot.
      if !DevSessionMirror.exists {
        DevSessionMirror.save(stored)
      }
#endif
      return stored
    }
#if DEBUG && (targetEnvironment(simulator) || os(macOS))
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

  /// `userInitiated` is the difference between "the user signed out" and "the backend
  /// rejected our refresh token". Only the first may delete the shared dev session:
  /// kino.pub rotates refresh tokens, so when several debug builds share one file the
  /// slowest of them gets a 400 for a token another build already replaced. Deleting on
  /// that path wipes a session that is alive everywhere else and sends every platform
  /// back to the activation screen.
  func clear(userInitiated: Bool) {
    storage.clear()
#if DEBUG && (targetEnvironment(simulator) || os(macOS))
    if userInitiated {
      DevSessionMirror.delete()
    }
#endif
  }

  func clear() {
    clear(userInitiated: true)
  }

}
