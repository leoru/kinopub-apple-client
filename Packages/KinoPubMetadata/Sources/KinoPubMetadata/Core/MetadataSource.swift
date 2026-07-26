import Foundation

/// A read-only external catalog. Sources that don't implement a capability
/// return the protocol defaults (empty / nil) — that is not an error.
public protocol MetadataSource: Sendable {
  var id: MetadataSourceID { get }
  var isConfigured: Bool { get }

  func artwork(for identity: MediaIdentity) async throws -> Artwork?
  func cast(for identity: MediaIdentity) async throws -> [CastMember]
  func schedule(for identity: MediaIdentity, season: Int) async throws -> [EpisodeSchedule]
  func awards(for identity: MediaIdentity) async throws -> [Award]
  func nextEpisode(for identity: MediaIdentity) async throws -> EpisodeRef?
  func segments(for identity: MediaIdentity, season: Int, episode: Int) async throws -> SkipSegments?
  /// Full title overlay in one shot when the source can batch (TMDB append_to_response).
  func titleMetadata(for identity: MediaIdentity) async throws -> TitleMetadata?
  /// Person bio / birthday when the source knows a person id (TMDB `/3/person/{id}`).
  func personMetadata(id: Int) async throws -> PersonMetadata?
}

public extension MetadataSource {
  func artwork(for identity: MediaIdentity) async throws -> Artwork? { nil }
  func cast(for identity: MediaIdentity) async throws -> [CastMember] { [] }
  func schedule(for identity: MediaIdentity, season: Int) async throws -> [EpisodeSchedule] { [] }
  func awards(for identity: MediaIdentity) async throws -> [Award] { [] }
  func nextEpisode(for identity: MediaIdentity) async throws -> EpisodeRef? { nil }
  func segments(for identity: MediaIdentity, season: Int, episode: Int) async throws -> SkipSegments? { nil }
  func titleMetadata(for identity: MediaIdentity) async throws -> TitleMetadata? { nil }
  func personMetadata(id: Int) async throws -> PersonMetadata? { nil }
}
