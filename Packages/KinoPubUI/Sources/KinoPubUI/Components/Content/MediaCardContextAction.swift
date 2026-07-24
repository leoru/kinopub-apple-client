//
//  MediaCardContextAction.swift
//

import Foundation
import SwiftUI

/// One entry in a card's long-press menu. Titles are resolved by the app so this
/// package stays free of localization tables.
public struct MediaCardContextAction: Identifiable {
  public let id: String
  public let title: String
  public let systemImage: String
  public let role: ButtonRole?
  public let handler: () -> Void

  public init(id: String,
              title: String,
              systemImage: String,
              role: ButtonRole? = nil,
              handler: @escaping () -> Void) {
    self.id = id
    self.title = title
    self.systemImage = systemImage
    self.role = role
    self.handler = handler
  }
}
