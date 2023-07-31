//
//  MediaItemView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend

struct MediaItemView: View {
  
  var mediaItem: MediaItem
  
#if os(iOS)
  @Environment(\.horizontalSizeClass) private var sizeClass
#endif
  
  var toolbarItemPlacement: ToolbarItemPlacement {
    #if os(iOS)
    .topBarTrailing
    #elseif os(macOS)
    .navigation
    #endif
  }
  
  var body: some View {
    WidthThresholdReader(widthThreshold: 520) { proxy in
      ScrollView(.vertical) {
        VStack(spacing: 16) {
          headerView
          
          Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            MediaItemDescriptionCard(mediaItem: mediaItem)
            MediaItemFieldsCard(mediaItem: mediaItem)
          }
          .containerShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .fixedSize(horizontal: false, vertical: true)
          .padding([.horizontal, .bottom], 16)
          .frame(maxWidth: 1200)
        }
      }
    }
    .background(Color.KinoPub.background)
    .background()
    .toolbar {
      ToolbarItem(placement: toolbarItemPlacement) {
        Button {
          
        } label: {
          Image(systemName: "square.and.arrow.up")
        }
      }
    }
  }
  
  var headerView: some View {
    MediaItemHeaderView(size: .standard, mediaItem: mediaItem)
  }
}

struct MediaItemView_Previews: PreviewProvider {
  struct Preview: View {
    var body: some View {
      MediaItemView(mediaItem: MediaItem.mock())
    }
  }
  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}

