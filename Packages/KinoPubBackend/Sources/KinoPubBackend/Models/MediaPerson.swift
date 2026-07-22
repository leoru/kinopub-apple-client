//
//  MediaPerson.swift
//
//

import Foundation

/// Someone to list the catalog by. kino.pub has no people directory — `/v1/items`
/// filters on the name as written in the credits — so a name and which credit it came
/// from is the whole of a person's identity here.
public struct MediaPerson: Hashable, Identifiable {

  public enum Role: String, Hashable {
    /// The `actor` and `director` parameters of `/v1/items`.
    case actor
    case director

    public var titleKey: String {
      switch self {
      case .actor: return "Cast"
      case .director: return "Director"
      }
    }
  }

  public let name: String
  public let role: Role

  public var id: String { "\(role.rawValue):\(name)" }

  public init(name: String, role: Role) {
    self.name = name
    self.role = role
  }
}
