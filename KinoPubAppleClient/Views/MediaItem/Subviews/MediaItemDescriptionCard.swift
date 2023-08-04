//
//  MediaItemDescriptionView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import SkeletonUI

struct MediaItemDescriptionCard: View {

  var mediaItem: MediaItem
  var isSkeleton: Bool

  var body: some View {
    VStack(alignment: .leading) {
      Label(mediaItem.localizedTitle ?? "", systemImage: "movieclapper")
        .foregroundStyle(Color.KinoPub.text)
        .font(Font.KinoPub.header)
        .skeleton(enabled: isSkeleton)
      plot
      metaIcons
        .padding(.top, 8)
    }
  }

  var metaIcons: some View {
    HStack(content: {
      metaIcon(text: "1080p")
      metaIcon(text: "AC3")
      metaIcon(text: "CC")
      Spacer()
      actionIcons
    })
  }

  var plot: some View {
    Text(mediaItem.plot)
      .font(Font.KinoPub.small)
      .foregroundStyle(Color.KinoPub.text)
      .padding(.top, 8)
      .skeleton(with: isSkeleton, animated: nil)
      .multilineSkeleton(enabled: isSkeleton)
  }

  func metaIcon(text: String) -> some View {
    Text(text)
      .overlay(
        RoundedRectangle(cornerRadius: 5)
          .stroke(Color.KinoPub.text, lineWidth: 1)
          .padding(.all, -3)
      )
      .foregroundStyle(Color.KinoPub.text)
      .font(.system(size: 12))
      .padding(.horizontal, 5)
      .skeleton(enabled: isSkeleton, size: CGSize(width: 60, height: 20))

  }

  var actionIcons: some View {
    HStack {
      Button(action: {}, label: {
        Image(systemName: "eye").foregroundStyle(Color.KinoPub.text)
          .skeleton(enabled: isSkeleton, size: CGSize(width: 30, height: 30))
      })
      Button(action: {}, label: {
        Image(systemName: "folder").foregroundStyle(Color.KinoPub.text)
          .skeleton(enabled: isSkeleton, size: CGSize(width: 30, height: 30))
      })
      Button(action: {}, label: {
        Image(systemName: "bell").foregroundStyle(Color.KinoPub.text)
          .skeleton(enabled: isSkeleton, size: CGSize(width: 30, height: 30))
      })
    }

  }
}

struct MediaItemDescriptionCard_Previews: PreviewProvider {
  struct Preview: View {
    var body: some View {
      MediaItemDescriptionCard(mediaItem: MediaItem.mock(), isSkeleton: true)
    }
  }

  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}
