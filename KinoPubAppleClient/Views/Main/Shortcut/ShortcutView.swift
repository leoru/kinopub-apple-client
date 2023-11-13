//
//  ShortcutView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubUI

struct ShortcutSelectionView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var shortcut: MediaShortcut
  @Binding var mediaType: MediaType
  
  var body: some View {
    ZStack {
      Color.KinoPub.background.edgesIgnoringSafeArea(.all)
      VStack {
        HStack {
          mediaTypesPicker
          shortcutPicker
        }
#if os(macOS)
        KinoPubButton(title: "Apply".localized, color: .green) {
          dismiss()
        }
        .frame(width: 100, height: 30)
        .padding()
#endif
      }
      
    }
    .background(Color.KinoPub.background)
    .presentationDetents([.height(180.0)])
    .presentationDragIndicator(.visible)
    
  }
  
  var shortcutPicker: some View {
    Picker("", selection: $shortcut) {
      ForEach(MediaShortcut.allCases) { shortcut in
        Text(shortcut.title.localized)
          .tag(shortcut)
      }
    }
#if os(iOS)
    .pickerStyle(.wheel)
#endif
#if os(macOS)
    .pickerStyle(.radioGroup)
#endif
    .padding()
  }
  var mediaTypesPicker: some View {
    Picker("", selection: $mediaType) {
      ForEach(MediaType.allCases) { type in
        Text(type.title.localized)
          .tag(type)
      }
    }
#if os(iOS)
    .pickerStyle(.wheel)
#endif
#if os(macOS)
    .pickerStyle(.radioGroup)
#endif
    .padding()
  }
}

struct ShortcutSelectionView_Previews: PreviewProvider {
  static var previews: some View {
    ShortcutSelectionView(shortcut: .constant(.fresh), mediaType: .constant(.movie))
  }
}
