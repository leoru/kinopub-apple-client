//
//  VoteData.swift
//

import Foundation

/// `/v1/items/vote` → `{voted, total, positive, negative, rating}` (counts arrive as strings).
public struct VoteData: Codable {
  public let voted: Bool
  public let total: String?
  public let positive: String?
  public let negative: String?
  public let rating: Int?

  public init(
    voted: Bool,
    total: String? = nil,
    positive: String? = nil,
    negative: String? = nil,
    rating: Int? = nil
  ) {
    self.voted = voted
    self.total = total
    self.positive = positive
    self.negative = negative
    self.rating = rating
  }

  public var totalCount: Int? { total.flatMap(Int.init) }
  public var positiveCount: Int? { positive.flatMap(Int.init) }
  public var negativeCount: Int? { negative.flatMap(Int.init) }
}
