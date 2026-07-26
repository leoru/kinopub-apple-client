//
//  MediaType.swift
//
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation

public enum MediaType: String, Codable, CaseIterable, Identifiable {
  case movie
  case serial
  case threeD = "3D"
  case concert
  case documovie
  case docuserial
  case tvshow

  public var id: Self {
    return self
  }

  /// Localization key for filters / tabs (often plural: "Movies").
  public var titleKey: String {
    switch self {
    case .movie: return "Movie"
    case .concert: return "Concert"
    case .documovie: return "Documentary"
    case .docuserial: return "Documentary Series"
    case .serial: return "TV Series"
    case .threeD: return "3D"
    case .tvshow: return "TV Show"
    }
  }

  /// Singular label for an item's Type row in Information.
  public var singularTitleKey: String {
    switch self {
    case .movie: return "MediaType_Movie"
    case .concert: return "MediaType_Concert"
    case .documovie: return "MediaType_Documentary"
    case .docuserial: return "MediaType_DocumentarySeries"
    case .serial: return "MediaType_TVSeries"
    case .threeD: return "MediaType_3D"
    case .tvshow: return "MediaType_TVShow"
    }
  }

  public var title: String { titleKey }
}
