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
  
  public enum HeaderSize: Double, RawRepresentable {
    case standard = 1.0
    case reduced = 0.5
  }
  
  public var headerSize: HeaderSize
  public var mediaItem: MediaItem
  public var linkProvider: NavigationLinkProvider
  public var isSkeleton: Bool
  
  public init(size: HeaderSize = .standard,
              mediaItem: MediaItem,
              linkProvider: NavigationLinkProvider,
              isSkeleton: Bool) {
    self.headerSize = size
    self.mediaItem = mediaItem
    self.isSkeleton = isSkeleton
    self.linkProvider = linkProvider
  }
  
  var body: some View {
    ZStack {
      image
        .padding(.top, -150 * headerSize.rawValue)
      VStack {
        Spacer()
        HStack {
          if let seasons = mediaItem.seasons, !seasons.isEmpty {
            NavigationLink(value: linkProvider.seasons(for: seasons)) {
              Text("Seasons")
                .modifier(KinoPubButtonTextStyle())
            }.buttonStyle(KinoPubButtonStyle(buttonColor: .green))
          } else {
            NavigationLink(value: linkProvider.player(for: mediaItem)) {
              Text("Watch")
                .modifier(KinoPubButtonTextStyle())
            }.buttonStyle(KinoPubButtonStyle(buttonColor: .green))
          }
          NavigationLink(value: linkProvider.trailerPlayer(for: mediaItem)) {
            Text("Trailer")
              .modifier(KinoPubButtonTextStyle())
          }.buttonStyle(KinoPubButtonStyle(buttonColor: .gray))
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
    MediaItemHeaderView(size: .standard,
                        mediaItem: MediaItem.mock(),
                        linkProvider: MainRoutesLinkProvider(),
                        isSkeleton: true)
  }
}
