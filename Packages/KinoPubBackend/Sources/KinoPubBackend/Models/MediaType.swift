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
  
  public var title: String {
    switch self {
    case .movie: return "Movie"
    case .concert: return "Concert"
    case .documovie: return "Documental"
    case .docuserial: return "Documental Series"
    case .serial: return "Serial"
    case .threeD: return "3D"
    case .tvshow: return "TV Show"
    }
  }
}
