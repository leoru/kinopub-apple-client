//
//  ExpandableText.swift
//
//

import Foundation
import SwiftUI

/// Text clamped to a line count, with a More button that only appears when the text
/// is genuinely longer than that. Truncation is detected by asking whether the full
/// text fits in the clamped frame rather than guessing from character count.
public struct ExpandableText: View {

  private let text: String
  private let lineLimit: Int
  private let font: Font
  private let buttonFont: Font

  @State private var isTruncated = false
  @State private var isExpanded = false

  public init(_ text: String, lineLimit: Int = 3, font: Font = .body, buttonFont: Font = .body) {
    self.text = text
    self.lineLimit = lineLimit
    self.font = font
    self.buttonFont = buttonFont
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(text)
        .font(font)
        .lineLimit(isExpanded ? nil : lineLimit)
        .multilineTextAlignment(.leading)
        .background {
          // Sized to the clamped text: if the unclamped copy fits, there is nothing
          // hidden; if it doesn't, ViewThatFits falls through and flags truncation.
          ViewThatFits(in: .vertical) {
            Text(text).font(font).hidden()
            Color.clear.onAppear { isTruncated = true }
          }
          .hidden()
        }

      if isTruncated {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
          Text(isExpanded ? "Less" : "More")
            .font(buttonFont)
        }
        // No `.buttonBorderShape` here: it needs macOS 14 and this package still
        // supports 13.
        .buttonStyle(.bordered)
      }
    }
  }
}
