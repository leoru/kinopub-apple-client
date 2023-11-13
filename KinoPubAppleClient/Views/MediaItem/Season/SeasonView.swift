//
//  SeasonView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 4.11.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend

struct SeasonView: View {
  @StateObject private var model: SeasonModel
  
  init(model: @autoclosure @escaping () -> SeasonModel) {
    _model = StateObject(wrappedValue: model())
  }
  
  var cellSize: Double { 140 }
  
  var body: some View {
    VStack {
      listView
    }
    .navigationTitle(model.season.fixedTitle)
    .background(Color.KinoPub.background)
  }
  
  var gridLayout: [GridItem] {
    [GridItem(.adaptive(minimum: cellSize), spacing: 16, alignment: .top)]
  }
  
  var listView: some View {
    ScrollView {
      LazyVGrid(columns: gridLayout, content: {
        ForEach(model.season.episodes, id: \.id) { item in
          NavigationLink(value: model.linkProvider.player(for: model.filledEpisode(item))) {
            SeasonItemView(episode: item)
              .padding(.bottom, 16)
          }
#if os(macOS)
          .buttonStyle(PlainButtonStyle())
#endif
        }
      })
      .padding(.horizontal, 16)
    }
  }
}
