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
  private var errorHandler: ErrorHandler
  public var linkProvider: NavigationLinkProvider
  public var mediaItemId: Int
  
  @Published public var mediaItem: MediaItem = MediaItem.mock()
  @Published public var itemLoaded: Bool = false

  init(mediaItemId: Int,
       itemsService: VideoContentService,
       linkProvider: NavigationLinkProvider,
       errorHandler: ErrorHandler) {
    self.itemsService = itemsService
    self.mediaItemId = mediaItemId
    self.linkProvider = linkProvider
    self.errorHandler = errorHandler
  }

  func fetchData() {
    Task {
      do {
        mediaItem = try await itemsService.fetchDetails(for: "\(mediaItemId)").item
        itemLoaded = true
      } catch {
        errorHandler.setError(error)
      }
    }
  }

}
