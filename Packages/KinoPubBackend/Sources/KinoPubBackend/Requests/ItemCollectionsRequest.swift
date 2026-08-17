//
//  ItemCollectionsRequest.swift
//

import Foundation

/// Which collections a title sits in — the reverse of `/v1/collections/view`.
///
/// 🔎 **Captured from the PWA, not from the vendor docs**, and captured on the other
/// host branch: `api.ios-kp.store/api2/v1.1/items/collections/{id}`. Whether our base
/// host answers the same path under `/v1` was unknown when this was written, so the
/// caller treats a failure as "no collections" and logs what came back — see
/// `docs/providers/kinopub/collections.md`.
///
/// The payload is `Collection` with two counters that exist nowhere else (`views`,
/// `watchers`) and no `wide` poster.
public struct ItemCollectionsRequest: Endpoint {

  private let itemId: Int

  public init(itemId: Int) {
    self.itemId = itemId
  }

  public var path: String { "/v1/items/collections/\(itemId)" }
  public var method: String { "GET" }
  public var parameters: [String: Any]? { nil }
  public var headers: [String: String]? { nil }
  public var forceSendAsGetParams: Bool { false }
}
