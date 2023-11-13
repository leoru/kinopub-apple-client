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
  var onDownload: (DownloadableMediaItem,FileInfo) -> Void
  var onWatchedToggle: () -> Void
  var onBookmarkHandle: () -> Void
  @State private var selectedDownloadableItem: DownloadableMediaItem?
  @State private var showDownloadPicker: Bool = false
  @State private var showDownloadableItemPicker: Bool = false

  var body: some View {
    VStack(alignment: .leading) {
      Label(mediaItem.localizedTitle, systemImage: "movieclapper")
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
      Button(action: {
        if mediaItem.seasons?.count ?? 0 > 0 {
          showDownloadableItemPicker = true
        } else {
          self.selectedDownloadableItem = DownloadableMediaItem(name: mediaItem.title, 
                                                                files: mediaItem.files,
                                                                mediaItem: mediaItem,
                                                                watchingMetadata: WatchingMetadata(id: mediaItem.id, video: nil, season: nil))
          showDownloadPicker = true
        }
      }, label: {
        image(imageName: "arrow.down.circle")
      })
      // Picker to select quality of the item to download
      .confirmationDialog("", isPresented: $showDownloadPicker, titleVisibility: .hidden) {
        ForEach(selectedDownloadableItem?.files ?? []) { file in
          Button(file.quality) {
            guard let selectedDownloadableItem else {
              return
            }
            onDownload(selectedDownloadableItem, file)
          }
        }
      }
      // Picker to select episode or entire media to download
      .confirmationDialog("", isPresented: $showDownloadableItemPicker, titleVisibility: .hidden) {
        ForEach(mediaItem.downloadableItems) { item in
          Button(item.name) {
            selectedDownloadableItem = item
            showDownloadPicker = true
          }
        }
      }
#if os(macOS)
      .buttonStyle(PlainButtonStyle())
#endif
      
      Button(action: { onWatchedToggle() }, label: {
        image(imageName: "eye")
      })
#if os(macOS)
      .buttonStyle(PlainButtonStyle())
#endif
      
      Button(action: { onBookmarkHandle() }, label: {
        image(imageName: "folder")
      })
#if os(macOS)
      .buttonStyle(PlainButtonStyle())
#endif
    }
    
  }
  
  func image(imageName: String) -> some View {
    Image(systemName: imageName)
      .foregroundStyle(Color.KinoPub.accent)
      .font(.title)
      .skeleton(enabled: isSkeleton, size: CGSize(width: 30, height: 30))
  }
}

struct MediaItemDescriptionCard_Previews: PreviewProvider {
  struct Preview: View {
    var body: some View {
      MediaItemDescriptionCard(mediaItem: MediaItem.mock(), isSkeleton: true, onDownload: { _,_  in }, onWatchedToggle: {}, onBookmarkHandle: {})
    }
  }
  
  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}
