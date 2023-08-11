//
//  ShortcutView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

struct ShortcutSelectionView: View {
  @Binding var shortcut: MediaShortcut
  @Binding var mediaType: MediaType

  var body: some View {
    ZStack {
      Color.KinoPub.background.edgesIgnoringSafeArea(.all)
      HStack {
        mediaTypesPicker
        shortcutPicker
      }
    }
    .background(Color.KinoPub.background)
    .presentationDetents([.height(180.0)])
    .presentationDragIndicator(.visible)
  }

  var shortcutPicker: some View {
    Picker("Choose shortcut", selection: $shortcut) {
      ForEach(MediaShortcut.allCases) { shortcut in
        Text(shortcut.title.localized)
          .tag(shortcut)
      }
    }
    .pickerStyle(.wheel)
    .padding()
  }
  var mediaTypesPicker: some View {
    Picker("Choose media type", selection: $mediaType) {
      ForEach(MediaType.allCases) { type in
        Text(type.title.localized)
          .tag(type)
      }
    }
    .pickerStyle(.wheel)
    .padding()
  }
}

struct ShortcutSelectionView_Previews: PreviewProvider {
  static var previews: some View {
    ShortcutSelectionView(shortcut: .constant(.fresh), mediaType: .constant(.movie))
  }
}
