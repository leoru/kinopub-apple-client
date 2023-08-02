//
//  MediaCatalog.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import Combine

@MainActor
class MediaCatalog: ObservableObject {
  
  private var itemsService: VideoContentService
  private var bag = Set<AnyCancellable>()
  
  @Published public var items: [MediaItem] = []
  @Published public var pagination: Pagination?
  @Published public var contentType: MediaType = .movie
  @Published public var shortcut: MediaShortcut = .hot
  
  var title: String {
    contentType.title
  }
  
  init(itemsService: VideoContentService) {
    self.itemsService = itemsService
    subscribe()
  }
  
  
  func fetchItems() async {
    do {
      let page = pagination != nil ? pagination!.current + 1 : nil
      let data = try await itemsService.fetch(shortcut: shortcut, contentType: contentType, page: page)
      self.items.append(contentsOf: data.items)
      pagination = data.pagination
    } catch {
      Logger.app.debug("fetch items error: \(error)")
    }
  }
  
  func loadMoreContent(after item: MediaItem) {
    guard let pagination = pagination else {
      return
    }
    
    let thresholdIndex = self.items.index(self.items.endIndex, offsetBy: -1)
    if thresholdIndex == self.items.firstIndex(of: item), pagination.current <= pagination.total {
      Logger.app.debug("load more content after item: \(item.id)")
      Task {
        await fetchItems()
      }
    }
  }
  
  func refresh() {
    items.removeAll()
    pagination = nil
    Task {
      Logger.app.debug("refetch items")
      await fetchItems()
    }
  }
  
  private func subscribe() {
    $contentType.dropFirst().sink { [weak self] item in
      self?.refresh()
    }.store(in: &bag)
    
    $shortcut.dropFirst().sink { [weak self] _ in
      self?.refresh()
    }.store(in: &bag)
  }
  
}
