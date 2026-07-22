//
//  SubtitleOverlayView.swift
//  KinoPubAppleClient
//

import SwiftUI

/// One or two lines of subtitles, stacked at the bottom of the frame.
///
/// The second track sits directly under the first rather than across the screen: eyes
/// that have to travel from top to bottom miss both.
struct SubtitleOverlayView: View {
  let text: String
  var secondaryText: String?

  var body: some View {
    VStack(spacing: 6) {
      line(text, size: subtitleFontSize, weight: .semibold, opacity: 1)
      if let secondaryText, !secondaryText.isEmpty {
        line(secondaryText, size: secondaryFontSize, weight: .medium, opacity: 0.85)
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity)
    .allowsHitTesting(false)
  }

  private func line(_ text: String, size: CGFloat, weight: Font.Weight, opacity: Double) -> some View {
    Text(text)
      .font(.system(size: size, weight: weight))
      .multilineTextAlignment(.center)
      .foregroundStyle(.white.opacity(opacity))
      .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
  }

  private var subtitleFontSize: CGFloat {
#if os(tvOS)
    return 34
#else
    return 22
#endif
  }

  /// Smaller, so the pair reads as one block with an obvious first line.
  private var secondaryFontSize: CGFloat {
    subtitleFontSize * 0.8
  }
}

#Preview {
  ZStack {
    Color.black
    VStack {
      Spacer()
      SubtitleOverlayView(text: "I never thought it would end like this.",
                          secondaryText: "Я и не думал, что всё так закончится.")
    }
  }
}
