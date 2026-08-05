//
//  MarqueeText.swift
//  KinoPubUI
//
//  Focused overflowing labels scroll horizontally; Reduce Motion keeps truncation.
//

import SwiftUI

/// Single-line label that marquees when focused and truncated. Used for card /
/// episode titles and long sidebar names — not body copy.
public struct MarqueeText: View {
  private let text: String
  private let font: Font
  private let foreground: Color
  private let alignment: Alignment
  /// When true (default), expands to the parent's width for shelf captions.
  /// When false, hugs the glyph width so siblings (badges) can sit flush beside it.
  private let fillsWidth: Bool

  @Environment(\.isFocused) private var isFocused
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var textWidth: CGFloat = 0
  @State private var containerWidth: CGFloat = 0
  @State private var offset: CGFloat = 0
  @State private var runToken = 0

  public init(
    _ text: String,
    font: Font = TypeScale.cardTitle,
    foreground: Color = Color.KinoPub.text,
    alignment: Alignment = .leading,
    fillsWidth: Bool = true
  ) {
    self.text = text
    self.font = font
    self.foreground = foreground
    self.alignment = alignment
    self.fillsWidth = fillsWidth
  }

  private var isTruncated: Bool {
    textWidth > containerWidth + 1 && containerWidth > 0
  }

  public var body: some View {
    Text(text)
      .font(font)
      .foregroundStyle(foreground)
      .lineLimit(1)
      .background {
        Text(text)
          .font(font)
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)
          .hidden()
          .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
      }
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
      .offset(x: offset)
      .modifier(MarqueeWidthModifier(fillsWidth: fillsWidth, alignment: alignment))
      .clipped()
      .onChange(of: isFocused) { _, focused in
        runToken += 1
        if focused {
          startMarquee(token: runToken)
        } else {
          withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
        }
      }
      .accessibilityLabel(Text(text))
  }

  private func startMarquee(token: Int) {
    offset = 0
    guard isTruncated, !reduceMotion else { return }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(450))
      guard token == runToken, isFocused, isTruncated, !reduceMotion else { return }
      let travel = textWidth - containerWidth + 24
      let duration = min(max(Double(travel) / 40.0, 2.0), 8.0)
      withAnimation(.linear(duration: duration)) {
        offset = -travel
      }
    }
  }
}

private struct MarqueeWidthModifier: ViewModifier {
  let fillsWidth: Bool
  let alignment: Alignment

  func body(content: Content) -> some View {
    if fillsWidth {
      content.frame(maxWidth: .infinity, alignment: alignment)
    } else {
      content.fixedSize(horizontal: true, vertical: false)
    }
  }
}

#Preview("Marquee text") {
  MarqueeText(
    "Очень длинный заголовок карточки который не влезает в узкую колонку",
    font: TypeScale.cardTitle
  )
  .frame(width: 160)
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
