//
//  MediaShortcut.swift
//
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation

public enum MediaShortcut: String, Codable, CaseIterable, Identifiable {
  case hot
  case fresh
  case popular

  public var id: Self {
    return self
  }

  public var title: String {
    switch self {
    case .hot: return "Hot"
    case .fresh: return "Fresh"
    case .popular: return "Popular"
    }
  }
}
