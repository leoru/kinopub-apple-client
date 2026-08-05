//
//  MediaPerson.swift
//
//

import Foundation

/// Someone to list the catalog by. kino.pub has no people directory — `/v1/items`
/// filters on the name as written in the credits — so a name and which credit it came
/// from is the whole of a person's identity here.
///
/// Optional TMDB fields ride along from the cast rail so the person page can show a
/// photo and fetch a bio without a second name lookup. Equality stays name+role.
public struct MediaPerson: Hashable, Identifiable {

  public enum Role: String, Hashable {
    case actor
    case director

    public var titleKey: String {
      switch self {
      case .actor: return "Cast"
      case .director: return "Director"
      }
    }

    /// Query key for `/v1/items`. Docs list `[actor]`, but the live mobile API
    /// filters on `cast=` (community-verified); `director=` matches the docs.
    public var itemsQueryParameter: String {
      switch self {
      case .actor: return "cast"
      case .director: return "director"
      }
    }
  }

  public let name: String
  public let role: Role
  public let photoURL: URL?
  public let tmdbPersonId: Int?

  public var id: String { "\(role.rawValue):\(name)" }

  public init(name: String, role: Role, photoURL: URL? = nil, tmdbPersonId: Int? = nil) {
    self.name = name
    self.role = role
    self.photoURL = photoURL
    self.tmdbPersonId = tmdbPersonId
  }

  public static func == (lhs: MediaPerson, rhs: MediaPerson) -> Bool {
    lhs.name == rhs.name && lhs.role == rhs.role
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(role)
    hasher.combine(name)
  }
}
