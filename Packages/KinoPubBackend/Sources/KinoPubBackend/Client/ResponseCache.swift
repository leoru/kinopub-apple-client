//
//  ResponseCache.swift
//
//  Opt-in response cache for the API layer. Stores raw response *bytes* (not decoded
//  objects) keyed by request. Only requests that conform to `CacheableRequest` are
//  cached — we use it for reference data (genres, countries), not personalized shelves
//  (`ContentStore` owns those TTLs).
//

import Foundation

// MARK: - Policy

public enum CachePolicy {
  case noCache
  /// Kept in memory only; cleared on relaunch.
  case memory(ttl: TimeInterval)
  /// Persisted to disk; survives relaunches.
  case disk(ttl: TimeInterval)

  var ttl: TimeInterval? {
    switch self {
    case .noCache: return nil
    case .memory(let ttl), .disk(let ttl): return ttl
    }
  }

  var persistsToDisk: Bool {
    if case .disk = self { return true }
    return false
  }
}

// MARK: - Cacheable request

public protocol CacheableRequest {
  var cacheKey: String { get }
  var cachePolicy: CachePolicy { get }
}

public extension CacheableRequest where Self: Endpoint {
  /// Stable key derived from the path and sorted parameters (order-independent).
  var cacheKey: String {
    let query = parameters?
      .map { "\($0.key)=\($0.value)" }
      .sorted()
      .joined(separator: "&") ?? ""
    return "\(method) \(path)?\(query)"
  }
}

// MARK: - Cache

public protocol ResponseCaching: AnyObject {
  func data(for key: String) -> Data?
  func store(_ data: Data, for key: String, ttl: TimeInterval, persist: Bool)
  func remove(for key: String)
  func clear()
}

public final class ResponseCache: ResponseCaching {

  private struct MemoryEntry {
    let data: Data
    let expiry: Date
    var isExpired: Bool { Date() > expiry }
  }

  /// On-disk envelope. `key` is stored so a filename-hash collision can be treated as a miss.
  private struct DiskEntry: Codable {
    let key: String
    let expiry: Date
    let payload: Data
  }

  private let lock = NSLock()
  private var memory: [String: MemoryEntry] = [:]
  private let ioQueue = DispatchQueue(label: "com.kinopub.responsecache.io")
  private let directory: URL?

  public init(directoryName: String = "APIResponseCache") {
    let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    if let base {
      let dir = base.appendingPathComponent(directoryName, isDirectory: true)
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      self.directory = dir
    } else {
      self.directory = nil
    }
  }

  public func data(for key: String) -> Data? {
    lock.lock()
    if let entry = memory[key] {
      if entry.isExpired {
        memory[key] = nil
      } else {
        lock.unlock()
        return entry.data
      }
    }
    lock.unlock()

    guard let url = fileURL(for: key),
          let raw = try? Data(contentsOf: url),
          let entry = try? PropertyListDecoder().decode(DiskEntry.self, from: raw),
          entry.key == key else {
      return nil
    }
    if entry.expiry < Date() {
      try? FileManager.default.removeItem(at: url)
      return nil
    }
    lock.lock()
    memory[key] = MemoryEntry(data: entry.payload, expiry: entry.expiry)
    lock.unlock()
    return entry.payload
  }

  public func store(_ data: Data, for key: String, ttl: TimeInterval, persist: Bool) {
    let expiry = Date().addingTimeInterval(ttl)
    lock.lock()
    memory[key] = MemoryEntry(data: data, expiry: expiry)
    lock.unlock()

    guard persist, let url = fileURL(for: key) else { return }
    let entry = DiskEntry(key: key, expiry: expiry, payload: data)
    ioQueue.async {
      if let encoded = try? PropertyListEncoder().encode(entry) {
        try? encoded.write(to: url, options: .atomic)
      }
    }
  }

  public func remove(for key: String) {
    lock.lock()
    memory[key] = nil
    lock.unlock()
    if let url = fileURL(for: key) {
      ioQueue.async { try? FileManager.default.removeItem(at: url) }
    }
  }

  public func clear() {
    lock.lock()
    memory.removeAll()
    lock.unlock()
    guard let directory else { return }
    ioQueue.async {
      let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                   includingPropertiesForKeys: nil)) ?? []
      contents.forEach { try? FileManager.default.removeItem(at: $0) }
    }
  }

  /// Deterministic FNV-1a filename (`String.hashValue` is randomised per launch).
  private func fileURL(for key: String) -> URL? {
    guard let directory else { return nil }
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in key.utf8 {
      hash ^= UInt64(byte)
      hash = hash &* 0x100000001b3
    }
    return directory.appendingPathComponent(String(format: "%016llx.plist", hash))
  }
}
