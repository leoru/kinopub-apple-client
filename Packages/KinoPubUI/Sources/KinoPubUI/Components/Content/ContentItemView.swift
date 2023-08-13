//
//  ContentItemView.swift
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
    VStack(alignment: .center) {
      ZStack {
        image
        if !(mediaItem.skeleton ?? false) {
          ratingsBlock
        }
      }
      VStack(alignment: .center) {
        title
        subtitle
      }.padding(.horizontal, 8)
    }
    .background(Color.clear)
  }

  var image: some View {
    AsyncImage(url: URL(string: mediaItem.posters.medium)) { image in
      image.resizable()
        .renderingMode(.original)
        .posterStyle(size: .medium)
    } placeholder: {
      Color.KinoPub.skeleton
        .frame(width: PosterStyle.Size.medium.width,
               height: PosterStyle.Size.medium.height)
    }
    .cornerRadius(8)
    .skeleton(enabled: mediaItem.skeleton ?? false,
              size: CGSize(width: PosterStyle.Size.medium.width,
                           height: PosterStyle.Size.medium.height))
  }
  
  var ratingsBlock: some View {
    VStack {
      Spacer()
      ContentItemRatingView(imdbScore: mediaItem.imdbRating,
                            kinopoiskScore: mediaItem.kinopoiskRating)
      .skeleton(enabled: mediaItem.skeleton ?? false)
      .padding(.bottom, 8)
    }
  }

  var title: some View {
    Text(mediaItem.localizedTitle ?? "")
      .lineLimit(1)
      .font(.system(size: 16.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.text)
      .skeleton(enabled: mediaItem.skeleton ?? false)
  }

  var subtitle: some View {
    Text(mediaItem.originalTitle ?? "")
      .lineLimit(1)
      .font(.system(size: 14.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.subtitle)
      .skeleton(enabled: mediaItem.skeleton ?? false)
  }

}

#Preview {
  ContentItemView(mediaItem: MediaItem.mock(skeleton: true))
}
