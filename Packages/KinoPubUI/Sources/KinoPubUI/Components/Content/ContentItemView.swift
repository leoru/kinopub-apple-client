//
//  File.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

public struct ContentItemView: View {
  
  private var mediaItem: MediaItem
  
  init(mediaItem: MediaItem) {
    self.mediaItem = mediaItem
  }
  
  public var body: some View {
    VStack(alignment: .leading) {
      ZStack {
        image
        VStack {
          Spacer()
          ContentItemRatingView(imdbScore: mediaItem.imdbRating,
                                kinopoiskScore: mediaItem.kinopoiskRating)
          .padding(.bottom, 8)
        }
      }
      title
      subtitle
    }
  }
  
  var image: some View {
    AsyncImage(url: URL(string: mediaItem.posters.medium)) { image in
      image.resizable()
        .renderingMode(.original)
        .posterStyle(size: .medium)
    } placeholder: {
      ProgressView()
    }
    .cornerRadius(8)
  }
  
  var title: some View {
    Text(mediaItem.title)
      .lineLimit(1)
      .font(.system(size: 16.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.text)
  }
  
  var subtitle: some View {
    Text(mediaItem.title)
      .lineLimit(1)
      .font(.system(size: 14.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.subtitle)
  }
  
}

#Preview {
  ContentItemView(mediaItem: MediaItem.mock())
}
