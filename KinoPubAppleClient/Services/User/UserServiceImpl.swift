//
//  UserServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 9.08.2023.
//

import Foundation
import KinoPubBackend

final class UserServiceImpl: UserService {
  
  private var apiClient: APIClient
  
  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }
  
  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = ShortcutItemsRequest(shortcut: shortcut, contentType: contentType, page: page)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }
  
  func fetchUserData() async throws -> UserData {
    let request = UserDataRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: UserDataResponse.self)
    return response.user
  }
  
}
