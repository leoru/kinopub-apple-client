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
  public var isSkeleton: Bool

  public enum HeaderSize: Double, RawRepresentable {
    case standard = 1.0
    case reduced = 0.5
  }

  public init(size: HeaderSize = .standard, mediaItem: MediaItem, isSkeleton: Bool) {
    self.headerSize = size
    self.mediaItem = mediaItem
    self.isSkeleton = isSkeleton
  }

  var body: some View {
    ZStack {
      image
        .padding(.top, -200 * headerSize.rawValue)
      VStack {
        Spacer()
        HStack {

          NavigationLink(value: MainRoutes.player(mediaItem)) {
            Text("Смотреть")
          }
//          KinoPubButton(title: "Смотреть", color: .green) {
//            
//          }
          KinoPubButton(title: "Трейлер", color: .gray) {

          }
        }
        .padding(.all, 16)
      }
    }
    .frame(height: 200 * headerSize.rawValue)
    .contentShape(Rectangle())
    .skeleton(enabled: isSkeleton, size: CGSize(width: 300, height: 300))
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
    MediaItemHeaderView(size: .standard, mediaItem: MediaItem.mock(), isSkeleton: true)
  }
}
