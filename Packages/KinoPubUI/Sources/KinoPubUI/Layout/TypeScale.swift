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

  /// **The** running-text size on an item page. Everything that is prose or a
  /// label-and-value pair takes this: the hero's metadata row, synopsis and credit
  /// lines, the vote counts under the rating tiles, and every row of the information
  /// table. They used to be four hand-picked point sizes between 12 and 15 that were
  /// never quite the same as each other; one token means they cannot drift apart again.
  ///
  /// A text style rather than `.system(size:)`, so it tracks Dynamic Type. Add `.weight`
  /// where a value needs to stand out from its caption — never a size.
  /// It is `.body` — the platform's own running-text style — rather than a step down
  /// from it. The old sizes were all *below* body (12–15pt on a Mac, 20–25 on a TV):
  /// small enough that the synopsis read as a caption on the artwork instead of as the
  /// thing you are meant to read. Levelling them meant levelling **up**.
  public static let detailBody: Font = .body
  public static let filterControl: Font = .subheadline.weight(.semibold)
  public static let actionLabel: Font = .headline.weight(.semibold)
  public static let detailSection: Font = .title3.weight(.semibold)
  public static let settingsTitle: Font = .largeTitle.bold()
  public static let settingsTip: Font = .title3

  /// Rating digits on a poster's corner badge, next to the laurel-wing icon
  /// (`RatingBadgeView.wingHeight`). The nearest text style to the old fixed point
  /// size (13pt / 22pt on tvOS) on each platform, so it now tracks Dynamic Type
  /// instead of sitting still while the rest of the badge scales around it.
  public static let ratingBadge: Font = {
#if os(tvOS)
    .caption2.weight(.bold)
#else
    .footnote.weight(.bold)
#endif
  }()

  /// Large rating digits on the detail page's ratings row (`AggregateRatingLabel`) —
  /// nearest text style to the old fixed size (28pt / 44pt on tvOS), same reasoning
  /// as `ratingBadge`.
  public static let ratingAggregate: Font = {
#if os(tvOS)
    .title3.weight(.bold)
#else
    .title.weight(.bold)
#endif
  }()
}
