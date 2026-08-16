//
//  MediaLinksRequest.swift
//
//  Links for one media, so item details can be fetched without them.
//

import Foundation

public struct MediaLinksRequest: Endpoint {

  private let mediaId: Int

  /// - Parameter mediaId: kino.pub's `media` id — an episode's own `id`, or a film's
  ///   video id. **Not** the item id.
  public init(mediaId: Int) {
    self.mediaId = mediaId
  }

  public var path: String {
    "/v1/items/media-links"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    ["mid": mediaId]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
}
