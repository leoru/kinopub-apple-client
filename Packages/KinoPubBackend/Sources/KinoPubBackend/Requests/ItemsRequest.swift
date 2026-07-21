//
//  ItemsRequest.swift
//
//

import Foundation

/// The full catalog listing with sorting and filters — `/v1/items`.
public struct ItemsRequest: Endpoint {

  private let filter: LibraryFilter
  private let page: Int?

  public init(filter: LibraryFilter, page: Int? = nil) {
    self.filter = filter
    self.page = page
  }

  public var path: String {
    "/v1/items"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    var params: [String: Any] = ["sort": filter.sort.apiValue]
    if let type = filter.contentType {
      params["type"] = type.rawValue
    }
    if let genreID = filter.genreID {
      params["genre"] = "\(genreID)"
    }
    if let countryID = filter.countryID {
      params["country"] = "\(countryID)"
    }
    if let years = filter.years {
      params["year"] = years.apiValue
    }
    if let page {
      params["page"] = "\(page)"
    }
    return params
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}
