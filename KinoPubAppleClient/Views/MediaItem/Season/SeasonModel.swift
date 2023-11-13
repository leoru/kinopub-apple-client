//
//  SeasonModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 4.11.2023.
//

import Foundation
import KinoPubBackend

class SeasonModel: ObservableObject {

  public var season: Season
  public var linkProvider: NavigationLinkProvider

  init(season: Season, linkProvider: NavigationLinkProvider) {
    self.season = season
    self.linkProvider = linkProvider
  }
  
  func filledEpisode(_ episode: Episode) -> Episode {
    let episode = episode
    episode.seasonNumber = season.number
    episode.mediaId = season.mediaId
    return episode
  }
}
