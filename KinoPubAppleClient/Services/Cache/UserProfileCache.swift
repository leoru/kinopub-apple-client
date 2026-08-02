//
//  UserProfileCache.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import OSLog

/// Persists the sidebar profile (name, subscription days, avatar) to `Caches/`, so a
/// cold start paints the last known profile before the network answers — and an
/// offline start doesn't show a blank row. Same deal as `RowSnapshotStore`: a
/// missing or OS-purged snapshot just means "fetch fresh".
final class UserProfileCache {
  static let shared = UserProfileCache()

  private let userFileURL: URL
  private let avatarFileURL: URL

  init(directory: URL? = nil) {
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let dir = directory ?? caches.appendingPathComponent("KinoPubProfile", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.userFileURL = dir.appendingPathComponent("user.json")
    self.avatarFileURL = dir.appendingPathComponent("avatar")
  }

  func loadUser() -> UserData? {
    guard let data = try? Data(contentsOf: userFileURL) else { return nil }
    return try? JSONDecoder().decode(UserData.self, from: data)
  }

  func loadAvatar() -> Data? {
    try? Data(contentsOf: avatarFileURL)
  }

  func save(user: UserData) {
    do {
      let data = try JSONEncoder().encode(user)
      try data.write(to: userFileURL, options: [.atomic])
    } catch {
      Logger.app.error("UserProfileCache: save user failed: \(error.localizedDescription)")
    }
  }

  func saveAvatar(_ data: Data) {
    do {
      try data.write(to: avatarFileURL, options: [.atomic])
    } catch {
      Logger.app.error("UserProfileCache: save avatar failed: \(error.localizedDescription)")
    }
  }

  func clearAvatar() {
    try? FileManager.default.removeItem(at: avatarFileURL)
  }
}
