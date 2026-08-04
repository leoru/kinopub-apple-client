//
//  SettingsIconView.swift
//  KinoPubAppleClient
//

import SwiftUI

/// Apple Settings–style glyph in a colored rounded square.
struct SettingsIconView: View {
  let systemImage: String
  let color: Color
  var size: CGFloat = 23

  var body: some View {
    Image(systemName: systemImage)
      .font(.system(size: size * 0.52, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
  }
}
