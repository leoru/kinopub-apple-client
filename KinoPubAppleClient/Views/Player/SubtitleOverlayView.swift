//
//  SubtitleOverlayView.swift
//  KinoPubAppleClient
//

import SwiftUI

struct SubtitleOverlayView: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: subtitleFontSize, weight: .semibold))
      .multilineTextAlignment(.center)
      .foregroundStyle(.white)
      .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
      .padding(.horizontal, 24)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity)
      .allowsHitTesting(false)
  }

  private var subtitleFontSize: CGFloat {
#if os(tvOS)
    return 34
#else
    return 22
#endif
  }
}
