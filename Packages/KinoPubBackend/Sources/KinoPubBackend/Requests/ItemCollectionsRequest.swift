//
//  ItemCollectionsRequest.swift
//

import Foundation

/// Which collections a title sits in — the reverse of `/v1/collections/view`.
///
/// 🔴 **This one method does not live on our own host.** `/v1/items/collections/{id}`
/// answers **404** on `api.service-kp.com` (seen live 2026-08-17 for item 248); the
/// PWA reads it from the other branch, `api.ios-kp.store/api2/v1.1/…`, which is the
/// only place it has ever been seen answering. Hence `baseURLOverride` — the rest of
/// the app stays on the mirror the user signed in to.
///
/// The payload is `Collection` with two counters that exist nowhere else (`views`,
/// `watchers`) and no `wide` poster. See `docs/providers/kinopub/collections.md`.
public struct ItemCollectionsRequest: Endpoint {

  private let itemId: Int

  public init(itemId: Int) {
    self.itemId = itemId
  }

  /// The branch the PWA uses. Not configurable: it is not a mirror of our host, it is
  /// the only host that answers this path.
  public static let branchURL = URL(string: "https://api.ios-kp.store/api2/v1.1/")!

  public var baseURLOverride: URL? { Self.branchURL }

  // Relative to `branchURL`, so no leading slash — one would drop `/api2/v1.1`.
  public var path: String { "items/collections/\(itemId)" }
  public var method: String { "GET" }
  public var parameters: [String: Any]? { nil }
  public var headers: [String: String]? { nil }
  public var forceSendAsGetParams: Bool { false }
}
