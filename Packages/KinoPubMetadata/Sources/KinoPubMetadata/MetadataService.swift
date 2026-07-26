import Foundation
import OSLog
import KinoPubLogging

/// Facade over configured metadata sources. Failures are swallowed — callers
/// treat an empty `TitleMetadata` as "draw the kino.pub page as today".
public actor MetadataService {
  private let sources: [any MetadataSource]
  private let cache: MetadataCache

  public init(sources: [any MetadataSource], cache: MetadataCache = MetadataCache()) {
    self.sources = sources
    self.cache = cache
  }

  /// One call per detail page. Sources run in parallel; each contributes what it can.
  public func metadata(for identity: MediaIdentity) async -> TitleMetadata {
    var result = TitleMetadata()
    let configured = sources.filter(\.isConfigured)
    guard !configured.isEmpty else { return result }

    await withTaskGroup(of: TitleMetadata?.self) { group in
      for source in configured {
        group.addTask {
          do {
            if let batch = try await source.titleMetadata(for: identity) {
              return batch
            }
            // Fall back to piecemeal contributions.
            var part = TitleMetadata()
            part.attribution.insert(source.id)
            if let art = try await source.artwork(for: identity) {
              part.artwork = art
            }
            let cast = try await source.cast(for: identity)
            if !cast.isEmpty { part.cast = cast }
            if let next = try await source.nextEpisode(for: identity) {
              part.nextEpisode = next
            }
            return part
          } catch {
            Logger.metadata.error("Metadata source \(source.id.rawValue) failed: \(error.localizedDescription)")
            return nil
          }
        }
      }
      for await part in group {
        if let part { result.merge(part) }
      }
    }
    return result
  }

  public func schedule(for identity: MediaIdentity, season: Int) async -> [EpisodeSchedule] {
    var episodes: [EpisodeSchedule] = []
    for source in sources where source.isConfigured {
      do {
        let part = try await source.schedule(for: identity, season: season)
        if !part.isEmpty {
          episodes = part
          break
        }
      } catch {
        Logger.metadata.error("Schedule \(source.id.rawValue) s\(season) failed: \(error.localizedDescription)")
      }
    }
    return episodes
  }
}
