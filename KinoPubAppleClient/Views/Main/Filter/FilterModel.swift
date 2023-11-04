//
//  FilterModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 4.08.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

class FilterModel: ObservableObject {

  @Published var mediaType: MediaType = .movie

  @Published var yearFilterEnabled: Bool = false
  @Published var yearMin: Int = 1920
  @Published var yearMax: Int = 2023

  @Published var imdbFilterEnabled: Bool = false
  @Published var imdbMin: Int = 0
  @Published var imdbMax: Int = 0
  
  @Published var selectedGenre: MediaGenre?
  @Published var selectedCountry: Country?

}
