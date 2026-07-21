//
//  NavigationState.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI

class NavigationState: ObservableObject {
  @Published var columnVisibility = NavigationSplitViewVisibility.automatic
  @Published var selectedTab: NavigationTabs = .home
  @Published var mainRoutes: [MainRoutes] = []
  @Published var searchRoutes: [SearchRoutes] = []
  @Published var moviesRoutes: [CatalogRoutes] = []
  @Published var seriesRoutes: [CatalogRoutes] = []
  @Published var bookmarksRoutes: [BookmarksRoutes] = []
  @Published var downloadsRoutes: [DownloadsRoutes] = []
}
