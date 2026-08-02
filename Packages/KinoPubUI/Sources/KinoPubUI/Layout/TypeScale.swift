//
//  TypeScale.swift
//  KinoPubUI
//

import SwiftUI

/// Text styles for cards, shelves, heroes and chrome. Prefer these over `.system(size:)`.
public enum TypeScale {
  public static let cardTitle: Font = .headline
  public static let cardSubtitle: Font = .subheadline
  public static let cardMeta: Font = .caption.weight(.semibold)
  public static let rowHeader: Font = .title2.weight(.semibold)
  public static let rowCount: Font = .title3
  public static let rowChevron: Font = .headline.weight(.semibold)

  public static let heroTitle: Font = {
#if os(tvOS)
    .largeTitle.bold()
#elseif os(macOS)
    .title.bold()
#else
    .title2.bold()
#endif
  }()

  public static let heroSecondary: Font = .subheadline
  public static let filterControl: Font = .subheadline.weight(.semibold)
  public static let actionLabel: Font = .headline.weight(.semibold)
  public static let detailSection: Font = .title3.weight(.semibold)
  public static let settingsTitle: Font = .largeTitle.bold()
  public static let settingsTip: Font = .title3
}
