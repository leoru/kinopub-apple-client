//
//  MediaCapabilityBadgesView.swift
//  KinoPubUI
//

import SwiftUI
import KinoPubBackend

/// Renders `MediaCapabilityBadges` as compact system-looking capsules.
public struct MediaCapabilityBadgesView: View {
  public enum Mode {
    case poster
    case detail
  }

  private let badges: MediaCapabilityBadges
  private let mode: Mode

  public init(badges: MediaCapabilityBadges, mode: Mode = .detail) {
    self.badges = badges
    self.mode = mode
  }

  public var body: some View {
    let chips = mode == .poster ? badges.posterChips : badges.detailChips
    if !chips.isEmpty {
      HStack(spacing: 6) {
        ForEach(chips, id: \.self) { chip in
          Text(chip)
            .font(Self.font)
            .foregroundStyle(.white)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, Self.verticalPadding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .accessibilityLabel(Text(chip))
        }
      }
    }
  }

#if os(tvOS)
  static let font: Font = .caption.weight(.semibold)
  static let horizontalPadding: CGFloat = 8
  static let verticalPadding: CGFloat = 4
#else
  static let font: Font = .caption2.weight(.semibold)
  static let horizontalPadding: CGFloat = 6
  static let verticalPadding: CGFloat = 2
#endif
}

#Preview("Capability badges") {
  VStack(alignment: .leading, spacing: 20) {
    MediaCapabilityBadgesView(
      badges: MediaCapabilityBadges(is4K: true, isHDR: true),
      mode: .poster
    )
    MediaCapabilityBadgesView(
      badges: MediaCapabilityBadges(
        is4K: true,
//        isHDR: true,
        is3D: true,
        ageRating: "18+",
        hasClosedCaptions: true,
//        languages: ["RU"],
//        audioChannelHint: "DD"
      ),
      mode: .detail
    )
  }
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
