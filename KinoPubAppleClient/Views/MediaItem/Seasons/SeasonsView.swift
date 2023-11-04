//
//  SeasonsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 4.11.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend

struct SeasonsView: View {
  @StateObject private var model: SeasonsModel

  init(model: @autoclosure @escaping () -> SeasonsModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    VStack {
      listView
    }
    .navigationTitle("Seasons")
    .background(Color.KinoPub.background)
  }

  var listView: some View {
    List(model.seasons) { season in
      NavigationLink(value: model.linkProvider.season(for: season)) {
        Text(season.fixedTitle)
      }
    }
    .scrollContentBackground(.hidden)
  }
}
