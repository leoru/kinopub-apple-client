//
//  FilteDataServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 23.08.2023.
//

import Foundation
import KinoPubBackend

final class FilteDataServiceImpl: FilterDataService {
  
  private var apiClient: APIClient
  
  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }
  
  func fetchGenres() async throws -> [MediaGenre] {
    let request = GenresRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<MediaGenre>.self)
    return response.items
  }
  
  func fetchCountries() async throws -> [Country] {
    let request = CountriesRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<Country>.self)
    return response.items
  }
  
}
