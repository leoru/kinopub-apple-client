//
//  SeasonsModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 4.11.2023.
//

import Foundation
import KinoPubBackend

class SeasonsModel: ObservableObject {

  public var seasons: [Season]
  public var linkProvider: NavigationLinkProvider

  init(seasons: [Season], linkProvider: NavigationLinkProvider) {
    self.seasons = seasons
    self.linkProvider = linkProvider
  }
  
}
