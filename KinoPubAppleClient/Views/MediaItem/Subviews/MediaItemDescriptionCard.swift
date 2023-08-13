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
  @State private var showDownloadPicker: Bool = false
  
  var onDownload: (FileInfo) -> Void
  
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
      Button(action: { showDownloadPicker = true }, label: {
        image(imageName: "arrow.down.circle")
      })
      .confirmationDialog("", isPresented: $showDownloadPicker, titleVisibility: .hidden) {
        ForEach(mediaItem.videos?.first?.files ?? []) { file in
          Button(file.quality) {
            onDownload(file)
          }
        }
      }
#if os(macOS)
      .buttonStyle(PlainButtonStyle())
#endif
      
      Button(action: {}, label: {
        image(imageName: "eye")
      })
#if os(macOS)
      .buttonStyle(PlainButtonStyle())
#endif
      
      Button(action: {}, label: {
        image(imageName: "folder")
      })
#if os(macOS)
      .buttonStyle(PlainButtonStyle())
#endif
      
      Button(action: {}, label: {
        image(imageName: "bell")
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
      MediaItemDescriptionCard(mediaItem: MediaItem.mock(), isSkeleton: true, onDownload: { _ in })
    }
  }
  
  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}
