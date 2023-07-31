//
//  ContentItemRatingView.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI

public struct ContentItemRatingView: View {
  
  var imdbScore: Double?
  var kinopoiskScore: Double?
  
  public var body: some View {
    HStack {
      imdbImage
      imdbRating
      kpImage
      kpRating
    }
    .padding(.horizontal, 15)
    .padding(.vertical, 4)
    .background(Color.KinoPub.selectionBackground)
    .cornerRadius(8)
    .opacity(isEmpty ? 0 : 1)
  }
  
  var isEmpty: Bool {
    imdbScore == nil && kinopoiskScore == nil
  }
  
  var imdbImage: some View {
    Image("imdb", bundle: .module)
      .resizable()
      .tint(.white)
      .colorInvert()
      .frame(width: 24, height: 24)
  }
  
  var kpImage: some View {
    Image("kinopoisk", bundle: .module)
      .resizable()
      .frame(width: 20, height: 20)
  }
  
  var imdbRating: some View {
    Text("\(imdbScore?.scoreFormatted ?? "0.0")")
      .foregroundColor(.white)
  }
  
  var kpRating: some View {
    Text("\(kinopoiskScore?.scoreFormatted ?? "0.0")")
      .foregroundColor(.white)
  }
  
}

#Preview {
  ContentItemRatingView(imdbScore: 5.0, kinopoiskScore: 5.0)
}
