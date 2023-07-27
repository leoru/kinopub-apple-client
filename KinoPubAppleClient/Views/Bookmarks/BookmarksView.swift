//
//  BookmarksView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//

import SwiftUI
import KinoPubUI

enum Category: String {
  case movies = "Movies"
  case series = "Series"
}

struct BookmarksView: View {
  @State private var selected = Category.movies
  
  var body: some View {
    NavigationView {
      VStack {
        ZStack {
          topSelector
        }
//        ContentItemsListView(items: [])
      }
      .navigationTitle("Bookmarks")
      .background(Color.KinoPub.background)
    }
  }
  
  var topSelector: some View {
    Picker("Choose item", selection: $selected) {
      Text("Movies")
        .tag(Category.movies)
      Text("Series")
        .tag(Category.series)
    }
    .pickerStyle(.segmented)
    .padding()
  }
}

struct BookmarksView_Previews: PreviewProvider {
  static var previews: some View {
    BookmarksView()
  }
}
