//
//  EmptyResponseData.swift
//
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation

/// Response for fire-and-forget mutations. Some endpoints (e.g. `/v1/history/clear-for-*`) return a
/// literal `null` body instead of `{"status":200}`; a required `status: Int` made that decode throw
/// and surface a bogus "API error". This decoder tolerates `null` / empty / non-object bodies.
public struct EmptyResponseData: Codable {
  public var status: Int?

  public init(status: Int? = nil) {
    self.status = status
  }

  public init(from decoder: Decoder) throws {
    let container = try? decoder.container(keyedBy: CodingKeys.self)
    status = try? container?.decodeIfPresent(Int.self, forKey: .status)
  }

  private enum CodingKeys: String, CodingKey {
    case status
  }
}
