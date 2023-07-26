//
//  MainView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//
import SwiftUI
import KinoPubUI

struct MainView: View {
  
  @ObservedObject private var catalog: MediaCatalog
  
  init(catalog: MediaCatalog) {
    self.catalog = catalog
  }
  
  var body: some View {
    NavigationView {
      VStack {
        ContentItemsListView()
      }
      .navigationTitle("Main")
      .background(Color.KinoPub.background)
      .onAppear(perform: {
        Task {
          await catalog.fetchItems()
        }
      })
    }
  }
}

struct MainView_Previews: PreviewProvider {
  static var previews: some View {
    MainView(catalog: MediaCatalog(itemsService: VideoContentServiceMock()))
  }
}