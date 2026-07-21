//
//  Posters.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Posters: Codable, Hashable {
  public let small: String
  public let medium: String
  public let big: String
  public let wide: String?
}

public extension Posters {
  /// The wide (landscape) artwork. The API serves the same id under a `/wide/` path
  /// segment, so when the field is absent we derive it from another size — the trick
  /// microiptv uses to stretch cover art as a backdrop.
  var wideURL: String? {
    if let wide, !wide.isEmpty { return wide }
    for candidate in [big, medium, small] where !candidate.isEmpty && candidate.contains("/item/") {
      return candidate
        .replacingOccurrences(of: "/item/big/", with: "/item/wide/")
        .replacingOccurrences(of: "/item/medium/", with: "/item/wide/")
        .replacingOccurrences(of: "/item/small/", with: "/item/wide/")
    }
    return nil
  }
}
