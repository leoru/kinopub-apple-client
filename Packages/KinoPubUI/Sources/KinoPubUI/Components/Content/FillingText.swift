//
//  FillingText.swift
//  KinoPubUI
//

import SwiftUI

/// Running text that takes **every line the space allows** and ellipsises at the last
/// one that fits.
///
/// `lineLimit(5)` cannot do this. It is a fixed count against a box measured in
/// points, so it either stops short of the bottom or asks for a line the frame has no
/// room for and gets clipped mid-glyph — and it does so differently at every Dynamic
/// Type size, which is exactly when it matters. This measures one line of the actual
/// font, divides, and hands `Text` the count that fits.
///
/// The measurement view sits in a `background`, so it is laid out but contributes no
/// size of its own.
public struct FillingText: View {
  private let text: String
  private let font: Font
  /// Never fewer than this, even in a box too short for it — a card with no readable
  /// text at all is worse than one whose last line is tight.
  private let minimumLines: Int

  @State private var lineHeight: CGFloat = 0

  public init(_ text: String, font: Font, minimumLines: Int = 1) {
    self.text = text
    self.font = font
    self.minimumLines = minimumLines
  }

  public var body: some View {
    GeometryReader { proxy in
      Text(text)
        .font(font)
        .lineLimit(lineLimit(in: proxy.size.height))
        .truncationMode(.tail)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .background(alignment: .topLeading) {
      Text(verbatim: "A")
        .font(font)
        .hidden()
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { lineHeight = $0 }
    }
  }

  private func lineLimit(in height: CGFloat) -> Int? {
    guard lineHeight > 0, height > 0 else { return nil }
    // A hair of tolerance: a line whose height divides to 4.98 is a fourth line the
    // layout will happily draw, and rounding it down wastes the row.
    return max(minimumLines, Int((height / lineHeight) + 0.02))
  }
}

#Preview("Filling text") {
  HStack(spacing: 16) {
    ForEach([80.0, 140.0, 220.0], id: \.self) { height in
      FillingText(String(repeating: "Знаете, насчёт данного фильма сложно сказать однозначно. ", count: 8),
                  font: .body)
        .foregroundStyle(.secondary)
        .frame(width: 200, height: height)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
  }
  .padding()
  .preferredColorScheme(.dark)
}
