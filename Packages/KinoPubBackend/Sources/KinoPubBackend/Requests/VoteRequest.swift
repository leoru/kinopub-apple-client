//
//  VoteRequest.swift
//

import Foundation

/// Casts a kino.pub thumbs vote — `GET /v1/items/vote?id=&like=`.
///
/// Semantics (verified against the live API / community client):
/// - `like=1` — thumbs up
/// - `like=0` — thumbs down
/// - Voting is one-shot: a response with `voted: false` means the account already voted.
///   There is no server read-back of "my vote"; clients remember it locally after a successful cast.
public struct VoteRequest: Endpoint {

  public var id: Int
  public var like: Int

  public init(id: Int, like: Int) {
    self.id = id
    self.like = like
  }

  public var path: String { "/v1/items/vote" }
  public var method: String { "GET" }
  public var parameters: [String: Any]? { ["id": id, "like": like] }
  public var headers: [String: String]? { nil }
  public var forceSendAsGetParams: Bool { true }
}
