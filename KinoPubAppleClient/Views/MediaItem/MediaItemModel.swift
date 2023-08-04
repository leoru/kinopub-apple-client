//
//  MediaItemModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 2.08.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging

@MainActor
class MediaItemModel: ObservableObject {

  private var itemsService: VideoContentService

  public var mediaItemId: Int
  @Published public var mediaItem: MediaItem = MediaItem.mock()
  @Published public var itemLoaded: Bool = false

  init(mediaItemId: Int, itemsService: VideoContentService) {
    self.itemsService = itemsService
    self.mediaItemId = mediaItemId
  }

  func fetchData() {
    Task {
      do {
        mediaItem = try await itemsService.fetchDetails(for: "\(mediaItemId)").item
        itemLoaded = true
      } catch {
        // TODO: error
      }
    }
  }

}
