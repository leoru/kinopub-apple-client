//
//  CapabilityGlyph.swift
//  KinoPubUI
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A technical/parental-advisory badge glyph from the catalogue — quality tier, 3D,
/// closed captions, audio description, or the age-rating checkmark.
///
/// Each asset already draws its own shape (a pill with the label baked in, or the
/// checkmark) — this only sizes and tints it. Same idiom as `MediaScoreLogo`: fixed
/// height, free width, `.template` rendering so the caller's foreground colour wins.
///
/// **A case here is not a claim that we show it.** kino.pub sends no HDR / Dolby
/// Vision / Dolby Atmos / MPAA flag, so `dolbyVision` / `dolbyAtmos` exist for
/// `MediaItemBadgeCardsSection`'s illustration-only `#Preview` — never appended to a
/// real badge list — and `tv-ma` / `R` / `subtitle` stay unreferenced entirely, for
/// the same reason: no signal to back them. See that section's doc comment.
public struct CapabilityGlyph: View {

  public enum Source: String {
    case quality4K = "4K"
    case qualityHD = "HD"
    case qualitySD = "SD"
    case stereoscopic3D = "3D"
    case closedCaptions = "CC"
    case audioDescription = "AD"
    /// The age-rating checkmark — a shape, not a specific rating board's mark, so it
    /// pairs honestly with any age string a source sends ("16+", "TV-14", …).
    case ageRatingCheckmark = "checkmark_csm"
    /// Illustration-only — see the type doc comment.
    case dolbyVision = "dolby-vision"
    case dolbyAtmos = "dolby-atmos"
  }

  private let source: Source
  private let height: CGFloat

  public init(_ source: Source, height: CGFloat) {
    self.source = source
    self.height = height
  }

  public var body: some View {
    Image(source.rawValue, bundle: .module)
      .renderingMode(.template)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: height)
      .fixedSize(horizontal: true, vertical: false)
  }
}

/// A round flag, keyed by a lowercase ISO 639-1 language code or an ISO 3166-1 country
/// code — both resolve to `flag_<code>` in `Media.xcassets`, so the same view serves a
/// language row and a country tag. The asset set is added separately from this type;
/// an unadded code simply renders nothing rather than a broken-image glyph.
public struct FlagGlyph: View {
  private let code: String
  private let diameter: CGFloat

  public init(code: String, diameter: CGFloat) {
    self.code = code.lowercased()
    self.diameter = diameter
  }

  public var body: some View {
    if let uiImage = platformImage(named: "flag_\(code)", in: .module) {
      uiImage
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }
  }
}

#if canImport(UIKit)
private func platformImage(named name: String, in bundle: Bundle) -> Image? {
  guard UIImage(named: name, in: bundle, compatibleWith: nil) != nil else { return nil }
  return Image(name, bundle: bundle)
}
#elseif canImport(AppKit)
private func platformImage(named name: String, in bundle: Bundle) -> Image? {
  guard bundle.image(forResource: name) != nil else { return nil }
  return Image(name, bundle: bundle)
}
#endif

#Preview("Capability glyphs") {
  HStack(spacing: 16) {
    CapabilityGlyph(.quality4K, height: 18)
    CapabilityGlyph(.qualityHD, height: 18)
    CapabilityGlyph(.qualitySD, height: 18)
    CapabilityGlyph(.stereoscopic3D, height: 18)
    CapabilityGlyph(.closedCaptions, height: 18)
    CapabilityGlyph(.audioDescription, height: 18)
    CapabilityGlyph(.ageRatingCheckmark, height: 24)
      .foregroundStyle(.green)
  }
  .foregroundStyle(.white)
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
