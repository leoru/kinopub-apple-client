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
  @Published var selectedTab: NavigationTabs = .main
  @Published var mainRoutes: [MainRoutes] = []
  @Published var bookmarksRoutes: [BookmarksRoutes] = []
  @Published var downloadsRoutes: [DownloadsRoutes] = []
}
