//
//  MediaItemFieldsCard.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

struct MediaItemFieldsCard: View {
  
  var mediaItem: MediaItem
  
  var body: some View {
    VStack(alignment: .leading) {
      Label("MediaItem_Data", systemImage: "book.pages")
        .foregroundStyle(Color.KinoPub.text)
        .font(Font.KinoPub.subheader)
      
      VStack {
        data(key: "MediaItem_Title", value: "\(mediaItem.originalTitle ?? "")")
        data(key: "MediaItem_Year", value: "\(mediaItem.year)")
        data(key: "MediaItem_Duration", value: "\(mediaItem.duration.total)")
        data(key: "MediaItem_Country", value: "\(mediaItem.countries.compactMap({ $0.title }).joined(separator: ","))")
        data(key: "MediaItem_Genre", value: "\(mediaItem.genres.compactMap({ $0.title ?? "" }).joined(separator: ","))")
        data(key: "MediaItem_Voice", value: "\(mediaItem.voice ?? "")")
        data(key: "MediaItem_Director", value: "\(mediaItem.director)")
        data(key: "MediaItem_Cast", value: "\(mediaItem.cast)")
      }.padding(.top, 8)
      
    }
  }
  
  func data(key: String, value: String) -> some View {
    HStack(content: {
      dataTitle(text: key)
      Spacer()
      dataValue(text: value)
    })
    .padding(.top, 8)
  }
  
  var plot: some View {
    Text(mediaItem.plot)
      .font(.system(size: 11))
      .foregroundStyle(Color.KinoPub.text)
      .padding(.top, 8)
  }
  
  func dataTitle(text: String) -> some View {
    Text(NSLocalizedString(text, comment: ""))
      .foregroundStyle(Color.KinoPub.subtitle)
      .font(Font.KinoPub.small)
      .padding(.horizontal, 5)
  }
  
  func dataValue(text: String) -> some View {
    Text(text)
      .foregroundStyle(Color.KinoPub.text)
      .font(Font.KinoPub.small)
      .padding(.horizontal, 5)
      .multilineTextAlignment(.trailing)
  }
  
  
}

struct MediaItemFieldsCard_Previews: PreviewProvider {
  struct Preview: View {
    var body: some View {
      MediaItemFieldsCard(mediaItem: MediaItem.mock())
    }
  }
  
  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}