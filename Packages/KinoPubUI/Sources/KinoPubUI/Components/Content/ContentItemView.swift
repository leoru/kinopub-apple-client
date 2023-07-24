//
//  File.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI

public struct ContentItemView: View {
  
  public var body: some View {
    VStack(alignment: .leading) {
      ZStack {
        image
        VStack {
          Spacer()
          ContentItemRatingView(imdbScore: "6.0",
                                kinopoiskScore: "6.0")
          .padding(.bottom, 8)
        }
      }
      title
      subtitle
    }
  }
  
  var image: some View {
    AsyncImage(url: nil) { image in
      image.resizable()
        .renderingMode(.original)
        .posterStyle(size: .medium)
    } placeholder: {
      Image("item_placeholder", bundle: .module)
        .resizable()
        .renderingMode(.original)
        .posterStyle(size: .medium)
    }
    .cornerRadius(8)
  }
  
  var title: some View {
    Text("Кевин Харт: Проверка реальности")
      .lineLimit(1)
      .font(.system(size: 16.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.text)
  }
  
  var subtitle: some View {
    Text("Kevin Hart: Reality Check")
      .lineLimit(1)
      .font(.system(size: 14.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.subtitle)
  }
  
}

#Preview {
  ContentItemView()
}
