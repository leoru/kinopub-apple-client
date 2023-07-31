//
//  MediaItemHeaderView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend

struct MediaItemHeaderView: View {
  
  public var headerSize: HeaderSize
  public var mediaItem: MediaItem
  
  public enum HeaderSize: Double, RawRepresentable {
    case standard = 1.0
    case reduced = 0.5
  }
  
  public init(size: HeaderSize = .standard, mediaItem: MediaItem) {
    self.headerSize = size
    self.mediaItem = mediaItem
  }
  
  var body: some View {
    ZStack {
      image
        .padding(.top, -200 * headerSize.rawValue)
    }
    .frame(height: 200 * headerSize.rawValue)
    .contentShape(Rectangle())
  }
  
  var image: some View {
    AsyncImage(url: URL(string: mediaItem.posters.big)) { image in
      image.resizable()
        .centerCropped()
    } placeholder: {
      Color.KinoPub.subtitle
    }
    .cornerRadius(8)
  }
}

struct MediaItemHeaderView_Previews: PreviewProvider {
  static var previews: some View {
    MediaItemHeaderView(size: .standard, mediaItem: MediaItem.mock())
  }
}
