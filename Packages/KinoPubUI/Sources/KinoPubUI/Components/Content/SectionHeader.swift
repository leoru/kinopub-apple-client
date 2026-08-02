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
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      title
        .font(TypeScale.rowHeader)
        .foregroundStyle(Color.KinoPub.text)

      if let count, !count.isEmpty {
        Text(count)
          .font(TypeScale.rowCount)
          .foregroundStyle(Color.KinoPub.subtitle)
      }

      if showsChevron {
        Image(systemName: "chevron.forward")
          .font(TypeScale.rowChevron)
          .foregroundStyle(Color.KinoPub.subtitle)
          .opacity(chevronOpacity)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
