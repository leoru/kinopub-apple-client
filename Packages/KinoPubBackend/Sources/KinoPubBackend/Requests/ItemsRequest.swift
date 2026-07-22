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
    // `actor` / `director`, matched on the name as it appears in the credits. Commas
    // and pluses are this parameter's OR and AND, so a single name goes as written.
    if let person = filter.person {
      params[person.role.rawValue] = person.name
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
