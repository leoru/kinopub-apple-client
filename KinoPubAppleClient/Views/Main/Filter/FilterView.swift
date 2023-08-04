//
//  FilterView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 4.08.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

struct FilterView: View {

  @StateObject private var model: FilterModel

  init(model: @autoclosure @escaping () -> FilterModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    NavigationView {
      HStack {
        Spacer()
        Form {
          typePicker
          yearSection
          imdbRatingSection
          buttonsSection
        }
      }
    }
    .navigationTitle("Filter")
    .navigationBarTitleDisplayMode(.inline)
  }

  var typePicker: some View {
    Picker("Type", selection: $model.mediaType) {
      ForEach(MediaType.allCases) { type in
        Text(type.title.localized)
          .tag(type)
      }
    }
  }

  var buttonsSection: some View {
    Section {
      Button("Clear") {

      }
      Button("Apply") {

      }
    }
  }

  var yearSection: some View {
    Section {
      Toggle("Release Year", isOn: $model.yearFilterEnabled)
      if model.yearFilterEnabled {
        numberPicker(title: "From", from: 1920, to: 2023, currentValue: $model.yearMin)
        numberPicker(title: "To", from: 1920, to: 2023, currentValue: $model.yearMax)
      }
    }
  }

  var imdbRatingSection: some View {
    Section {
      Toggle("IMDB Rating", isOn: $model.imdbFilterEnabled)
      if model.imdbFilterEnabled {
        numberPicker(title: "From", from: 0, to: 10, currentValue: $model.imdbMin)
        numberPicker(title: "To", from: 0, to: 10, currentValue: $model.imdbMax)
      }
    }
  }

  func numberPicker(title: String, from: Int, to: Int, currentValue: Binding<Int>) -> some View {
    Picker(title, selection: currentValue) {
      ForEach(from..<to+1) {
        Text("\($0)").tag($0)
      }
    }
  }
}
