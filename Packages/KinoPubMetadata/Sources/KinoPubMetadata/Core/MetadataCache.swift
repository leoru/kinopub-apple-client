import Foundation

/// Memory + disk cache with inflight dedup and negative caching.
public actor MetadataCache {
  public struct Entry: Codable, Sendable {
    public let storedAt: Date
    public let payload: Data
    /// `true` when the payload is a confirmed miss (no logo, no match, …).
    public let isNegative: Bool

    public init(storedAt: Date = Date(), payload: Data, isNegative: Bool = false) {
      self.storedAt = storedAt
      self.payload = payload
      self.isNegative = isNegative
    }
  }

  private let directory: URL
  private var memory: [String: Entry] = [:]
  private var inflight: [String: Task<Entry?, Never>] = [:]
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  public init(directory: URL? = nil) {
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    self.directory = directory ?? caches.appendingPathComponent("KinoPubMetadata", isDirectory: true)
    try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
  }

  public func entry(for key: String, ttl: TimeInterval) -> Entry? {
    if let memory = memory[key], Date().timeIntervalSince(memory.storedAt) < ttl {
      return memory
    }
    if let disk = loadFromDisk(key: key), Date().timeIntervalSince(disk.storedAt) < ttl {
      memory[key] = disk
      return disk
    }
    return nil
  }

  public func store(_ entry: Entry, for key: String) {
    memory[key] = entry
    saveToDisk(key: key, entry: entry)
  }

  /// Runs `produce` at most once per key while in flight; callers share the result.
  public func deduped(key: String, ttl: TimeInterval, produce: @escaping @Sendable () async -> Entry?) async -> Entry? {
    if let cached = entry(for: key, ttl: ttl) {
      return cached
    }
    if let existing = inflight[key] {
      return await existing.value
    }
    let task = Task<Entry?, Never> {
      await produce()
    }
    inflight[key] = task
    let result = await task.value
    inflight[key] = nil
    if let result {
      store(result, for: key)
    }
    return result
  }

  public func encode<T: Encodable>(_ value: T) throws -> Data {
    try encoder.encode(value)
  }

  public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    try decoder.decode(T.self, from: data)
  }

  // MARK: - Disk

  private func fileURL(for key: String) -> URL {
    let safe = key
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ":", with: "_")
      .replacingOccurrences(of: "?", with: "_")
      .replacingOccurrences(of: "&", with: "_")
    return directory.appendingPathComponent("\(safe).json")
  }

  private func loadFromDisk(key: String) -> Entry? {
    let url = fileURL(for: key)
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? decoder.decode(Entry.self, from: data)
  }

  private func saveToDisk(key: String, entry: Entry) {
    guard let data = try? encoder.encode(entry) else { return }
    try? data.write(to: fileURL(for: key), options: [.atomic])
  }
}
