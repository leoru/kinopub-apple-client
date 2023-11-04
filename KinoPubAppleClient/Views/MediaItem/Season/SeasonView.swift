//
//  SeasonView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 4.11.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend

struct SeasonView: View {
  @StateObject private var model: SeasonModel

  init(model: @autoclosure @escaping () -> SeasonModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    VStack {
      listView
    }
    .navigationTitle(model.season.title)
    .background(Color.KinoPub.background)
  }

  var listView: some View {
    Text("1")
    .scrollContentBackground(.hidden)
  }
}
