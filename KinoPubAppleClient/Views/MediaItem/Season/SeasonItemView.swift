//
//  SeasonItemView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 10.11.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubUI

public struct SeasonItemView: View {
  
  private var episode: Episode
  
  init(episode: Episode) {
    self.episode = episode
  }
  
  public var body: some View {
    VStack(alignment: .center) {
      ZStack {
        image
        VStack {
          Spacer()
          title
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
      }
    }
    .background(Color.clear)
  }
  
  var image: some View {
    AsyncImage(url: URL(string: episode.thumbnail)) { image in
      image.resizable()
        .renderingMode(.original)
        .posterStyle(size: .regular, orientation: .horizontal)
    } placeholder: {
      Color.KinoPub.skeleton
        .frame(width: PosterStyle.Size.regular.height,
               height: PosterStyle.Size.regular.width)
    }
    .cornerRadius(8)
  }
  
  var title: some View {
    Text(episode.fixedTitle)
      .padding(.vertical, 3)
      .padding(.horizontal, 6)
      .font(.system(size: 14.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.text)
      .background(Color.black.opacity(0.7))

  }
  
}

