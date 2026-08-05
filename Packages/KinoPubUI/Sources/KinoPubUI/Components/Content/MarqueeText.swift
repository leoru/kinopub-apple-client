//
//  MarqueeText.swift
//  KinoPubUI
//
//  tvOS: UILabel.enablesMarqueeWhenAncestorFocused — system marquee instead of "…".
//  Other platforms: single-line truncate (no focus marquee).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Single-line shelf / card title. On tvOS uses the system focus marquee so long
/// titles scroll instead of ending in an ellipsis while an ancestor is focused.
public struct MarqueeText: View {
  public enum Style: Sendable {
    case title
    case subtitle
    case meta

#if os(tvOS)
    var textStyle: UIFont.TextStyle {
      switch self {
      case .title: return .headline
      case .subtitle: return .callout
      case .meta: return .caption1
      }
    }
#endif
  }

  private let text: String
  private let font: Font
  private let foreground: Color
  private let alignment: Alignment
  /// When true (default), expands to the parent's width for shelf captions.
  /// When false, hugs the glyph width so siblings (badges) can sit flush beside it.
  private let fillsWidth: Bool
  private let style: Style

  public init(
    _ text: String,
    font: Font = TypeScale.cardTitle,
    foreground: Color = Color.KinoPub.text,
    alignment: Alignment = .leading,
    fillsWidth: Bool = true,
    style: Style = .title
  ) {
    self.text = text
    self.font = font
    self.foreground = foreground
    self.alignment = alignment
    self.fillsWidth = fillsWidth
    self.style = style
  }

  public var body: some View {
#if os(tvOS)
    NativeFocusMarqueeLabel(
      text: text,
      textStyle: style.textStyle,
      foreground: UIColor(foreground),
      alignment: nsTextAlignment
    )
    .modifier(MarqueeWidthModifier(fillsWidth: fillsWidth, alignment: alignment))
    .accessibilityLabel(Text(text))
#else
    Text(text)
      .font(font)
      .foregroundStyle(foreground)
      .lineLimit(1)
      .truncationMode(.tail)
      .modifier(MarqueeWidthModifier(fillsWidth: fillsWidth, alignment: alignment))
      .accessibilityLabel(Text(text))
#endif
  }

#if os(tvOS)
  private var nsTextAlignment: NSTextAlignment {
    switch alignment {
    case .center, .top, .bottom: return .center
    case .trailing, .topTrailing, .bottomTrailing: return .right
    default: return .left
    }
  }
#endif
}

#if os(tvOS)
/// System marquee: scrolls while any ancestor in the focus hierarchy is focused.
private struct NativeFocusMarqueeLabel: UIViewRepresentable {
  var text: String
  var textStyle: UIFont.TextStyle
  var foreground: UIColor
  var alignment: NSTextAlignment

  func makeUIView(context: Context) -> UILabel {
    let label = UILabel()
    label.numberOfLines = 1
    label.enablesMarqueeWhenAncestorFocused = true
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return label
  }

  func updateUIView(_ label: UILabel, context: Context) {
    label.text = text
    label.font = .preferredFont(forTextStyle: textStyle)
    label.textColor = foreground
    label.textAlignment = alignment
    label.enablesMarqueeWhenAncestorFocused = true
  }
}
#endif

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
