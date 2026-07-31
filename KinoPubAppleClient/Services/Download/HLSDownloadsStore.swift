//
//  HLSDownloadsStore.swift
//  KinoPubAppleClient
//
//  Persists metadata about downloaded HLS assets (.movpkg bundles produced by
//  AVAssetDownloadURLSession). Mirrors the style of `DownloadedFilesDatabase`.
//
//  Apple requires that we store the *relative* path of the downloaded asset and
//  reconstruct the absolute URL at use-time via NSHomeDirectory(), because the
//  sandbox container path can change between launches. We must NOT move the
//  .movpkg bundle ourselves.
//

import Foundation
import KinoPubBackend
import KinoPubKit
import KinoPubLogging
import OSLog

/// A record describing a fully-downloaded HLS asset.
public struct HLSDownloadedAsset: Codable, Equatable {
  /// Playable/identifying metadata (same type used by the mp4 download path).
  public let meta: DownloadMeta
  /// Path of the `.movpkg` bundle, relative to NSHomeDirectory().
  public let relativePath: String
  public let downloadDate: Date

  public init(meta: DownloadMeta, relativePath: String, downloadDate: Date) {
    self.meta = meta
    self.relativePath = relativePath
    self.downloadDate = downloadDate
  }

  /// Absolute on-disk URL of the `.movpkg` bundle, reconstructed for the current
  /// sandbox container. Apple-documented reconstruction pattern.
  public var localFileURL: URL {
    URL(fileURLWithPath: NSHomeDirectory() + "/" + relativePath)
  }

  public var fileExists: Bool {
    FileManager.default.fileExists(atPath: localFileURL.path)
  }
}

/// Persists `[HLSDownloadedAsset]` to a plist in the Documents directory and
/// provides reconciliation / removal helpers. Thread-safety: callers use it from
/// the main actor (matching the rest of the download code).
public final class HLSDownloadsStore {

  private let dataFileURL: URL

  public init() {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    self.dataFileURL = documents.appendingPathComponent("hlsDownloadedAssets.plist")
  }

  // MARK: - Read / Write

  public func readData() -> [HLSDownloadedAsset] {
    guard let data = try? Data(contentsOf: dataFileURL),
          let decoded = try? PropertyListDecoder().decode([HLSDownloadedAsset].self, from: data) else {
      return []
    }
    return decoded.sorted(by: { $0.downloadDate > $1.downloadDate })
  }

  public func writeData(_ assets: [HLSDownloadedAsset]) {
    if let data = try? PropertyListEncoder().encode(assets) {
      try? data.write(to: dataFileURL)
    }
  }

  public func save(_ asset: HLSDownloadedAsset) {
    var current = readData()
    // Replace any existing record for the same logical item/episode.
    current.removeAll(where: { Self.sameItem($0.meta, asset.meta) })
    current.append(asset)
    writeData(current)
    Logger.kit.debug("[HLS] saved asset for id: \(asset.meta.id) at \(asset.relativePath)")
  }

  // MARK: - Lookup

  /// Returns the downloaded asset matching the given playable item, if any and
  /// its bundle still exists on disk.
  public func asset(forId id: Int, video: Int?, season: Int?) -> HLSDownloadedAsset? {
    readData().first(where: {
      $0.meta.id == id
      && $0.meta.metadata.video == video
      && $0.meta.metadata.season == season
      && $0.fileExists
    })
  }

  // MARK: - Size

  /// On-disk size (in bytes) of the `.movpkg` directory for the given asset.
  public func diskSize(of asset: HLSDownloadedAsset) -> Int64 {
    Self.directorySize(at: asset.localFileURL)
  }

  // MARK: - Removal

  /// Deletes the `.movpkg` bundle from disk and removes the persisted record.
  public func remove(_ asset: HLSDownloadedAsset) {
    if asset.fileExists {
      try? FileManager.default.removeItem(at: asset.localFileURL)
    }
    var current = readData()
    current.removeAll(where: { $0.relativePath == asset.relativePath })
    writeData(current)
    Logger.kit.debug("[HLS] removed asset at \(asset.relativePath)")
  }

  // MARK: - Reconciliation

  /// Drops records whose `.movpkg` bundle no longer exists on disk (e.g. removed
  /// by the system to reclaim space). Returns the surviving records.
  @discardableResult
  public func reconcile() -> [HLSDownloadedAsset] {
    let current = readData()
    let alive = current.filter { $0.fileExists }
    if alive.count != current.count {
      writeData(alive)
      Logger.kit.debug("[HLS] reconciled, dropped \(current.count - alive.count) missing assets")
    }
    return alive
  }

  // MARK: - Orphan cleanup

  /// Reclaims orphaned `.movpkg` bundles. `AVAssetDownloadURLSession` writes downloads into
  /// `Library/com.apple.UserManagedAssets*` (NOT Documents — so they're invisible in the Files app),
  /// and a failed / cancelled / 429-retried download leaves its partial bundle behind: each retry
  /// starts a fresh bundle and abandons the previous one, so disk usage balloons well past what the
  /// user actually downloaded. This deletes every `.movpkg` there that isn't a saved download or one
  /// of `keepRelativePaths` (in-flight / interrupted partials we still track). Returns bytes freed.
  @discardableResult
  public func sweepOrphans(keepRelativePaths: Set<String> = []) -> Int64 {
    let referenced = Set(readData().map { $0.relativePath }).union(keepRelativePaths)
    // Safety net: also keep anything whose bundle filename matches a tracked download, in case the
    // stored relative path and the on-disk path don't compare identically.
    let referencedNames = Set(referenced.map { ($0 as NSString).lastPathComponent })
    let home = NSHomeDirectory()
    let fm = FileManager.default
    let libraryURL = URL(fileURLWithPath: home).appendingPathComponent("Library")
    guard let containers = try? fm.contentsOfDirectory(at: libraryURL, includingPropertiesForKeys: nil) else {
      return 0
    }
    var freed: Int64 = 0
    for container in containers where container.lastPathComponent.hasPrefix("com.apple.UserManagedAssets") {
      guard let bundles = try? fm.contentsOfDirectory(at: container, includingPropertiesForKeys: nil) else { continue }
      for bundle in bundles where bundle.pathExtension == "movpkg" {
        let relative = bundle.path.hasPrefix(home + "/") ? String(bundle.path.dropFirst(home.count + 1)) : bundle.path
        if referenced.contains(relative) { continue }
        if referencedNames.contains(bundle.lastPathComponent) { continue }
        let size = Self.directorySize(at: bundle)
        if (try? fm.removeItem(at: bundle)) != nil {
          freed += size
          Logger.kit.info("[HLS] swept orphan \(bundle.lastPathComponent) (freed \(size) bytes)")
        }
      }
    }
    return freed
  }

  /// Total on-disk size (bytes) of all saved HLS downloads.
  public func totalDownloadedBytes() -> Int64 {
    readData().filter { $0.fileExists }.reduce(0) { $0 + Self.directorySize(at: $1.localFileURL) }
  }

  // MARK: - Helpers

  static func sameItem(_ lhs: DownloadMeta, _ rhs: DownloadMeta) -> Bool {
    lhs.id == rhs.id && lhs.metadata.video == rhs.metadata.video && lhs.metadata.season == rhs.metadata.season
  }

  static func directorySize(at url: URL) -> Int64 {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: url,
                                         includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                                         options: [],
                                         errorHandler: nil) else {
      // url might be a single file (unlikely for movpkg) — fall back to attributes.
      let attrs = try? fm.attributesOfItem(atPath: url.path)
      return (attrs?[.size] as? Int64) ?? 0
    }
    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
      total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
    }
    return total
  }
}
