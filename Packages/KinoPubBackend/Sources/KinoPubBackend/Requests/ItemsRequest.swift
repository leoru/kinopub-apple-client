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
    // Commas are OR on `genre` — several genres ask for anything filed under any of
    // them. **Not true of `cast` / `director`**: those match the field as written, so a
    // comma there matches nothing and each name needs its own request (verified against
    // the live API 2026-08-17 — `director=Фил Лорд,Кристофер Миллер` answers empty).
    if !filter.genreIDs.isEmpty {
      params["genre"] = filter.genreIDs.map(String.init).joined(separator: ",")
    } else if let genreID = filter.genreID {
      params["genre"] = "\(genreID)"
    }
    if let countryID = filter.countryID {
      params["country"] = "\(countryID)"
    }
    if let years = filter.years {
      params["year"] = years.apiValue
    }
    // Popularity window — server-side (not a client facet). Sent for views/watchers
    // rankings; approximating via `created_at` would empty those lists.
    if let period = filter.period {
      params["period"] = period.rawValue
    }
    // `cast` / `director`, matched on the name as it appears in the credits — one name
    // per request, see the note above.
    // (`cast`, not the docs' `actor` — see `MediaPerson.Role.itemsQueryParameter`.)
    if let person = filter.person {
      params[person.role.itemsQueryParameter] = person.name
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
