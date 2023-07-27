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
  
  @Published public var items: [MediaItem] = []
  @Published public var pagination: Pagination?
  
  init(itemsService: VideoContentService) {
    self.itemsService = itemsService
  }
  
  func fetchItems() async {
    do {
      let data = try await itemsService.fetchItems()
      self.items.append(contentsOf: data.items)
      pagination = data.pagination
    } catch {
      
    }
  }
  
}
