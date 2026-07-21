//
//  GenresRequest.swift
//  
//
//  Created by Kirill Kunst on 14.08.2023.
//

import Foundation

public struct GenresRequest: Endpoint {

  private let contentType: MediaType?

  public init(contentType: MediaType? = nil) {
    self.contentType = contentType
  }

  /// Was pointing at `/v1/countries` — a copy-paste that would have filled the genre
  /// picker with country names.
  public var path: String {
    "/v1/genres"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    guard let contentType else { return nil }
    return ["type": contentType.rawValue]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}
