//
//  TVChannel.swift
//
//
//  A live sport TV channel from GET /v1/tv.
//

import Foundation

public struct TVChannel: Decodable, Identifiable, Hashable {
  public let id: Int
  public let title: String
  public let name: String?
  public let logo: String?
  public let stream: String

  private enum CodingKeys: String, CodingKey {
    case id, title, name, logos, stream
  }

  public init(id: Int, title: String, name: String? = nil, logo: String? = nil, stream: String) {
    self.id = id
    self.title = title
    self.name = name
    self.logo = logo
    self.stream = stream
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = (try? container.decode(Int.self, forKey: .id)) ?? 0
    title = (try? container.decode(String.self, forKey: .title)) ?? ""
    name = try? container.decode(String.self, forKey: .name)
    stream = (try? container.decode(String.self, forKey: .stream)) ?? ""

    // `logos` may be an object ({"s": "...", "m": "..."}), an array, or a plain string.
    if let object = try? container.decode([String: String].self, forKey: .logos) {
      logo = object["m"] ?? object["s"] ?? object.values.first
    } else if let array = try? container.decode([String].self, forKey: .logos) {
      logo = array.first
    } else if let single = try? container.decode(String.self, forKey: .logos) {
      logo = single
    } else {
      logo = nil
    }
  }
}

// MARK: - Playable

extension TVChannel: PlayableItem {
  public var files: [FileInfo] {
    [FileInfo(
      codec: "",
      w: 0,
      h: 0,
      quality: "",
      qualityID: 0,
      url: URLInfo(http: stream, hls: stream, hls4: stream, hls2: stream)
    )]
  }

  public var trailer: Trailer? { nil }
  public var subtitles: [Subtitle] { [] }
  public var metadata: WatchingMetadata { WatchingMetadata(id: id) }
}
