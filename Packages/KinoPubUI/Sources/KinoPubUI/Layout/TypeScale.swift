//
//  TypeScale.swift
//  KinoPubUI
//

import SwiftUI

/// Text styles for cards and shelves. Prefer these over `.system(size:)`.
public enum TypeScale {
  public static let cardTitle: Font = .headline
  public static let cardSubtitle: Font = .subheadline
  public static let cardMeta: Font = .caption.weight(.semibold)
  public static let rowHeader: Font = .title2.weight(.semibold)
  public static let rowCount: Font = .title3
  public static let rowChevron: Font = .headline.weight(.semibold)
}
