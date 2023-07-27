//
//  MainView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//
import SwiftUI
import KinoPubUI

struct MainView: View {
  
  @StateObject private var catalog: MediaCatalog = MediaCatalog(itemsService: AppContext.shared.contentService)
  
  var body: some View {
    NavigationView {
      VStack {
        ContentItemsListView(items: $catalog.items)
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
    MainView()
  }
}
