//
//  MediaCatalog.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KinoPubBackend

@MainActor
class MediaCatalog: ObservableObject {
  
  private var itemsService: VideoContentService
  
  @Published var items: [MediaItem] = []
  
  init(itemsService: VideoContentService) {
    self.itemsService = itemsService
  }
  
  func fetchItems() async {
    do {
      let newItems = try await itemsService.fetchItems()
      self.items.append(contentsOf: newItems)
    } catch {
      
    }
  }
  
}
