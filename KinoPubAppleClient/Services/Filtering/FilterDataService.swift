//
//  FilterDataService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 23.08.2023.
//

import Foundation
import KinoPubBackend

protocol FilterDataService {
  func fetchGenres() async throws -> [MediaGenre]
  func fetchCountries() async throws -> [Country]
}

protocol FilterDataServiceProvider {
  var filterDataService: FilterDataService { get set }
}
