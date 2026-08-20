//
//  SectionHeader.swift
//  KinoPubUI
//
//  Shared section title for rows, detail, person and grids.
//

import SwiftUI

/// Semantic section header with optional count, classic chevron and focusable link.
public struct SectionHeader: View {
  private let title: Text
  private let count: String?
  private let showsChevron: Bool
  private let leadingInset: CGFloat?

  @Environment(\.cardFocused) private var focused

  public init(
    _ titleKey: LocalizedStringKey,
    count: String? = nil,
    showsChevron: Bool = false,
    leadingInset: CGFloat? = nil
  ) {
    self.title = Text(titleKey)
    self.count = count
    self.showsChevron = showsChevron
    self.leadingInset = leadingInset
  }

  public init(
    title: String,
    count: String? = nil,
    showsChevron: Bool = false,
    leadingInset: CGFloat? = nil
  ) {
    self.title = Text(title)
    self.count = count
    self.showsChevron = showsChevron
    self.leadingInset = leadingInset
  }

  public var body: some View {
      HStack(alignment: .center, spacing: 8) {
      // `.secondary` the *hierarchical shape style*, not `Color.secondary`. They
      // resolve to the same colour over an opaque background, but only the shape
      // style gets the system's vibrancy treatment when the header sits over a
      // `Material` — which is what makes it read as part of the material rather than
      // painted on top of it. Section headers were `Color.KinoPub.text`
      // (= `Color.primary`, i.e. plain white in this app's forced-dark chrome), which
      // is the weight a *title* carries, not a section label.
      title
        .font(TypeScale.rowHeader)
        .foregroundStyle(.secondary)

      if let count, !count.isEmpty {
        // A step below the title so the two stay distinguishable now that the title
        // is itself secondary.
        Text(count)
          .font(TypeScale.rowCount)
          .foregroundStyle(.tertiary)
      }

      if showsChevron {
        Image(systemName: "chevron.forward")
          .font(TypeScale.rowChevron)
          .foregroundStyle(.tertiary)
          .opacity(chevronOpacity)
      }
    }
    // Hugs its own words. This used to be `maxWidth: .infinity` with the tap shape
    // over all of it, so the "see all" link — and anything hovering it — covered the
    // full width of the grid: a click level with the title but four columns to the
    // right navigated. The leading inset stays *outside* the shape for the same
    // reason. Callers that want the header to fill a row say so themselves.
    .contentShape(Rectangle())
    .padding(.leading, leadingInset ?? 0)
  }

  private var chevronOpacity: Double {
#if os(tvOS)
    focused ? 1 : 0
#else
    1
#endif
  }
}

#Preview("Section header") {
  VStack(alignment: .leading, spacing: 16) {
    SectionHeader("Continue Watching", count: "8", showsChevron: true)
      .environment(\.cardFocused, true)
    SectionHeader(title: "Credits", count: "24")
  }
  .padding()
  .background(Color.KinoPub.background)
  .preferredColorScheme(.dark)
}
