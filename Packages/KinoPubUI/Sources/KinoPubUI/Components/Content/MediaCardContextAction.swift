//
//  MediaCardContextAction.swift
//

import Foundation
import SwiftUI

/// Where a card is shown — artwork URL for debug (and later surface-specific
/// actions) differs between shelf lockups and featured banners.
public enum MediaCardContextSurface: Sendable {
  case shelf
  case banner
}

/// One entry in a card's long-press menu. Titles are resolved by the app so this
/// package stays free of localization tables.
public struct MediaCardContextAction: Identifiable {
  public let id: String
  public let title: String
  public let systemImage: String
  public let role: ButtonRole?
  /// When true, render as a menu `Toggle` (leading checkmark when on) — bookmark folders.
  public let isSelection: Bool
  public let isOn: Bool
  public let handler: () -> Void

  public init(id: String,
              title: String,
              systemImage: String,
              role: ButtonRole? = nil,
              isSelection: Bool = false,
              isOn: Bool = false,
              handler: @escaping () -> Void) {
    self.id = id
    self.title = title
    self.systemImage = systemImage
    self.role = role
    self.isSelection = isSelection
    self.isOn = isOn
    self.handler = handler
  }
}

/// Flat list with dividers and one-level submenus — enough for Apple-style card menus.
public enum MediaCardContextEntry: Identifiable {
  case action(MediaCardContextAction)
  /// `footer` sits below a divider (e.g. New Folder).
  case submenu(id: String,
               title: String,
               systemImage: String,
               children: [MediaCardContextAction],
               footer: [MediaCardContextAction])
  case divider(id: String)

  public var id: String {
    switch self {
    case .action(let action): return action.id
    case .submenu(let id, _, _, _, _): return id
    case .divider(let id): return id
    }
  }
}
