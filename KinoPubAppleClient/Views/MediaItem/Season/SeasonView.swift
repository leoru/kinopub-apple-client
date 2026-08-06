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
  
  /// Landscape tiles, so one episode column is as wide as a Continue Watching card.
#if os(tvOS)
  var cellSize: Double { 360 }
#else
  var cellSize: Double { 240 }
#endif

  var body: some View {
    VStack {
      listView
    }
    .platformNavigationTitle(model.season.fixedTitle)
    .background(Color.KinoPub.background)
  }

  var gridLayout: [GridItem] {
    [GridItem(.adaptive(minimum: cellSize), spacing: 16, alignment: .top)]
  }

  var listView: some View {
    ScrollView {
      LazyVGrid(columns: gridLayout, spacing: 16) {
        ForEach(model.season.episodes, id: \.id) { item in
          PlayerLink(route: model.linkProvider.player(for: model.filledEpisode(item)),
                     item: model.filledEpisode(item),
                     mode: .media) {
            // The one landscape card — same lockup as History / Continue Watching.
            MediaCardView(card: Self.card(for: item, in: model.season), caption: .always)
          }
#if os(tvOS)
          .buttonStyle(.borderless)
#else
          .buttonStyle(MediaCardButtonStyle())
#endif
        }
      }
      .padding(.horizontal, 16)
    }
  }

  private static func card(for episode: Episode, in season: Season) -> MediaCard {
    MediaCard(episode: episode,
              in: season,
              episodeLabel: "\("Episode".localized) \(episode.number)")
  }
}
