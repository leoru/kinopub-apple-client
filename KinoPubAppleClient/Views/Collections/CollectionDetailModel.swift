//
//  CollectionDetailModel.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging

/// One collection's full item grid — `/v1/collections/view` returns everything in
/// one response, so there is no pagination to drive here (unlike the paginated
/// catalog / search grids).
@MainActor
class CollectionDetailModel: ObservableObject {

  @Published public private(set) var title: String
  @Published public var items: [MediaItem] = []
  @Published public private(set) var isLoading: Bool = false
  @Published public private(set) var loadFailed: Bool = false
  @Published public private(set) var loadError: Error?

  private let collectionID: Int
  private let collectionsService: CollectionsService
  private let errorHandler: ErrorHandler

  init(collection: Collection, collectionsService: CollectionsService, errorHandler: ErrorHandler) {
    self.collectionID = collection.id
    self.title = collection.title
    self.collectionsService = collectionsService
    self.errorHandler = errorHandler
  }

  func fetch() async {
    isLoading = items.isEmpty
    defer { isLoading = false }
    do {
      let (collection, items) = try await collectionsService.fetchCollection(id: collectionID)
      title = collection.title
      self.items = items
      loadFailed = false
      loadError = nil
    } catch {
      Logger.app.debug("fetch collection \(self.collectionID) error: \(error)")
      if self.items.isEmpty {
        loadFailed = true
        loadError = error
      } else {
        errorHandler.setError(error)
      }
    }
  }
}
