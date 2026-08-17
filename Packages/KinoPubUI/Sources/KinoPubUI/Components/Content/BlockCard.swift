//
//  BlockCard.swift
//  KinoPubUI
//
//  One card shape for every page "block" on the pointer platforms.
//

import SwiftUI

/// The card every block-shaped section is built from — reviews, facts, stills,
/// information columns. **One component, configured**: a block does not get its own
/// card because it is a different block, and two blocks side by side are the same
/// shape, the same fill and the same corner radius or they are a bug.
///
/// Two kinds, one look:
///
/// - `.interactive` — the whole card is the control. Press and pointer feedback come
///   from the card, so the content inside must not also be tappable.
/// - `.flat` — the card is a surface. It holds its own rows, any of which may be
///   controls (the table shape), or none at all.
///
/// **Fill is a `Material`, never a colour.** The detail page sits on an ambient wash
/// of the title's own artwork; a card painted in a fixed grey stops belonging to it,
/// and a material keeps sampling whatever the page is showing. Materials also do
/// their own Reduce Transparency / Increase Contrast degradation, which is why this
/// does not route through `kinoGlass` — glass is chrome floating *over* content, and
/// a block card is content.
///
/// tvOS is not a customer of this yet (its media surfaces are TVUIKit), but the card
/// compiles there and takes the system `.card` button style when interactive, so
/// nothing here has to be re-decided if a TV block ever wants it.
/// How a `BlockCard` behaves. Top-level rather than nested in the generic card, so a
/// call site can name it (`BlockCardKind.link(value:)`) without naming the card's
/// content type.
public enum BlockCardKind {
  /// The card is the control.
  case interactive(action: () -> Void)
  /// The card is the control, and what it does is navigate. A `NavigationLink` rather
  /// than a `Button` calling `push`, so Back, drag-to-open and the pointer
  /// affordances are the system's.
  case link(value: any Hashable)
  /// The card is a surface; whatever is inside owns its own interactions.
  case flat
}

public struct BlockCard<Content: View>: View {

  public typealias Kind = BlockCardKind

  private let kind: Kind
  private let width: CGFloat?
  private let height: CGFloat?
  /// Fill the height a rail hands down, rather than the card's natural one.
  private let fillsHeight: Bool
  private let content: Content

  @State private var isHovered = false

  public init(
    _ kind: Kind = .flat,
    width: CGFloat? = nil,
    height: CGFloat? = nil,
    fillsHeight: Bool = false,
    @ViewBuilder content: () -> Content
  ) {
    self.kind = kind
    self.width = width
    self.height = height
    self.fillsHeight = fillsHeight
    self.content = content()
  }

  public var body: some View {
    switch kind {
    case .flat:
      surface
    case .interactive(let action):
      control { Button(action: action) { surface } }
    case .link(let value):
      control { NavigationLink(value: value) { surface } }
    }
  }

  /// Both control kinds wear the same style, hover and press — a card that navigates
  /// must not look different from one that does something else.
  @ViewBuilder
  private func control(@ViewBuilder _ content: () -> some View) -> some View {
    content()
#if os(tvOS)
      // The system card style: focus scale, highlight and parallax are Apple's.
      .buttonStyle(.card)
#else
      .buttonStyle(BlockCardPressStyle())
      .onHover { isHovered = $0 }
      .pointingHandCursorOnHover()
#endif
  }

  /// The inner frame comes **before** the padding on purpose: it is what stretches the
  /// content to the card's height, so a `Spacer` in the caller's stack can push a
  /// footer to the bottom. Sizing only the outer frame leaves the content at its
  /// natural height, pinned to the top, and every `Spacer` inside it collapsing to
  /// `minLength`.
  private var surface: some View {
    content
      .frame(maxWidth: .infinity,
             maxHeight: fillsHeight ? .infinity : nil,
             alignment: .topLeading)
      .padding(BlockMetrics.padding)
      .frame(width: width, height: height, alignment: .topLeading)
      .frame(maxHeight: fillsHeight ? .infinity : nil)
      .background(fill, in: BlockMetrics.shape)
      .contentShape(BlockMetrics.shape)
  }

  /// Hover deepens the material instead of tinting it — the one move that reads as
  /// "raised" without introducing a colour the page did not already have.
  private var fill: Material {
    isHovered ? .thickMaterial : .regularMaterial
  }
}

#if !os(tvOS)
/// Press feedback only. No hover scale, no shadow — hover is the material swap on the
/// card itself, and focus chrome is the system's business.
private struct BlockCardPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.spring(response: 0.2, dampingFraction: 0.9), value: configuration.isPressed)
  }
}
#endif

// MARK: - Rail

/// A row of `BlockCard`s: fixed height, horizontal scroll, page inset applied once.
///
/// The height is fixed rather than tallest-card-wins because the cards hold prose of
/// wildly different lengths — a rail that sizes itself to its longest review is a
/// rail whose height changes per title.
public struct BlockRail<Content: View>: View {
  private let height: CGFloat?
  private let inset: CGFloat
  private let spacing: CGFloat
  private let content: Content

  public init(
    height: CGFloat? = nil,
    inset: CGFloat,
    spacing: CGFloat = BlockMetrics.spacing,
    @ViewBuilder content: () -> Content
  ) {
    self.height = height
    self.inset = inset
    self.spacing = spacing
    self.content = content()
  }

  public var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(alignment: .top, spacing: spacing) {
        content
      }
      .frame(height: height)
      .scrollTargetLayout()
      .padding(.horizontal, inset)
    }
    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    // Cards are all one width, so aligning to them lands a card edge at the inset
    // instead of stopping mid-card. The system owns the deceleration.
    .scrollTargetBehavior(.viewAligned)
  }
}

// MARK: - Metrics

/// Card geometry, in one place, so two blocks cannot drift apart.
public enum BlockMetrics {
#if os(tvOS)
  public static let cornerRadius: CGFloat = 20
  public static let padding: CGFloat = 24
  public static let spacing: CGFloat = 24
  /// A card holding running text: wide enough for a readable measure, tall enough for
  /// a heading, a few lines and a footer.
  public static let textCardWidth: CGFloat = 520
  public static let textCardHeight: CGFloat = 300
#elseif os(macOS)
  public static let cornerRadius: CGFloat = 14
  public static let padding: CGFloat = 16
  public static let spacing: CGFloat = 12
  public static let textCardWidth: CGFloat = 340
  public static let textCardHeight: CGFloat = 190
#else
  public static let cornerRadius: CGFloat = 14
  public static let padding: CGFloat = 14
  public static let spacing: CGFloat = 10
  public static let textCardWidth: CGFloat = 300
  public static let textCardHeight: CGFloat = 190
#endif

  public static var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
  }
}

// MARK: - Preview

#Preview("Block cards") {
  ScrollView {
    VStack(alignment: .leading, spacing: 24) {
      SectionHeader("Flat — the card is a surface", leadingInset: 20)
      BlockRail(height: BlockMetrics.textCardHeight, inset: 20) {
        ForEach(0..<4, id: \.self) { index in
          BlockCard(width: BlockMetrics.textCardWidth, fillsHeight: true) {
            VStack(alignment: .leading, spacing: 8) {
              Text("Card \(index + 1)")
                .font(.headline)
              Text("Fixed height, horizontal scroll, page inset applied once by the rail.")
                .font(TypeScale.detailBody)
                .foregroundStyle(.secondary)
              Spacer(minLength: 0)
              Text("Footer")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
          }
        }
      }

      SectionHeader("Interactive — the card is the control", leadingInset: 20)
      BlockRail(height: 120, inset: 20) {
        ForEach(0..<4, id: \.self) { index in
          BlockCard(.interactive(action: {}),
                    width: BlockMetrics.textCardWidth,
                    fillsHeight: true) {
            VStack(alignment: .leading, spacing: 6) {
              Text("Card \(index + 1)")
                .font(.headline)
              Text("Hover deepens the material; press scales it.")
                .font(TypeScale.detailBody)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .padding(.vertical, 24)
  }
  .background {
    // Something for the material to sample — a flat fill makes every card look painted on.
    LinearGradient(colors: [.indigo, .black, .teal],
                   startPoint: .topLeading,
                   endPoint: .bottomTrailing)
      .ignoresSafeArea()
  }
  .preferredColorScheme(.dark)
}
