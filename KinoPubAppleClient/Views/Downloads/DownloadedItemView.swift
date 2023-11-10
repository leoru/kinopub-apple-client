//
//  DownloadedItemView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 8.08.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubUI

public struct DownloadedItemView: View {
  
  private var mediaItem: DownloadMeta
  private var progress: Float?
  private var onDownloadStateChange: (Bool) -> Void
  
  public init(mediaItem: DownloadMeta,
              progress: Float?,
              onDownloadStateChange: @escaping (Bool) -> Void) {
    self.mediaItem = mediaItem
    self.progress = progress
    self.onDownloadStateChange = onDownloadStateChange
  }
  
  public var body: some View {
    HStack(alignment: .center) {
      image
        
      VStack(alignment: .leading) {
        title
        subtitle
      }.padding(.all, 5)
      
      if let progress = progress {
        Spacer()
        if progress != 1.0 {
          ProgressButton(progress: progress) { state in
            onDownloadStateChange(state == .pause)
          }
          .padding(.trailing, 16)
        }
      } else {
        Spacer()
      }
    }
    .padding(.vertical, 8)
  }
  
  var image: some View {
    AsyncImage(url: URL(string: mediaItem.imageUrl)) { image in
      image.resizable()
        .renderingMode(.original)
        .posterStyle(size: .small, orientation: .vertical)
    } placeholder: {
      Color.KinoPub.skeleton
        .frame(width: PosterStyle.Size.small.width,
               height: PosterStyle.Size.small.height)
    }
    .cornerRadius(8)
  }
  
  var title: some View {
    Text(mediaItem.localizedTitle)
      .lineLimit(1)
      .font(.system(size: 14.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.text)
      .padding(.bottom, 10)
  }
  
  var subtitle: some View {
    Text(mediaItem.originalTitle)
      .lineLimit(1)
      .font(.system(size: 12.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.subtitle)
  }
  
}

#Preview {
  DownloadedItemView(mediaItem: DownloadMeta.make(from: DownloadableMediaItem(name: "", files: [], mediaItem: MediaItem.mock())), progress: nil) { _ in
    
  }
}

