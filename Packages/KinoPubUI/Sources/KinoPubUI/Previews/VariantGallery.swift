//
//  VariantGallery.swift
//  KinoPubUI
//
//  Home for the "2–3 variants on a named axis" rule in
//  AGENTS.md.
//
//  Convention:
//  - One file per ambiguous piece, named `<Thing>Variants.swift`, in this folder.
//  - Each variant gets a *named axis* — what actually differs (density, motion,
//    interaction), not "v1 / v2".
//  - Variants are fully interactive with realistic content. A static mock is not
//    a variant.
//  - The whole folder is `#if DEBUG`: nothing here ships.
//  - Once the user picks one, promote it into the real component and DELETE the
//    variants file. A stale gallery is worse than no gallery.
//

#if DEBUG
import SwiftUI

/// Lays candidate variants out side by side with their axis labels, so the
/// choice is between visibly different things rather than three near-identical
/// screenshots.
public struct VariantGallery<Content: View>: View {
  private let title: String
  private let axis: String
  private let content: Content

  public init(_ title: String, axis: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.axis = axis
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.title2.weight(.semibold))
          .foregroundStyle(Color.KinoPub.text)
        Text("Axis: \(axis)")
          .font(.caption)
          .foregroundStyle(Color.KinoPub.subtitle)
      }

        VStack(alignment: .leading, spacing: 32) {
        content
      }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color.KinoPub.background)
  }
}

/// One labelled candidate inside a `VariantGallery`.
public struct Variant<Content: View>: View {
  private let name: String
  private let content: Content

  public init(_ name: String, @ViewBuilder content: () -> Content) {
    self.name = name
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      content
      Text(name)
        .font(.caption.weight(.medium))
        .foregroundStyle(Color.KinoPub.subtitle)
    }
  }
}

// MARK: - Worked example

/// Exercises `kinoGlass` and the opaque path it falls back to. Doubles as the
/// reference for how a variants file is shaped.
///
/// `accessibilityReduceTransparency` and `colorSchemeContrast` are **read-only**
/// in `EnvironmentValues`, so the degraded state cannot be faked here — toggle
/// Reduce Transparency / Increase Contrast on the device to see `kinoGlass`
/// switch. The second tile draws the substitute directly so the two are
/// comparable side by side.
#Preview("KinoGlass — glass vs substitute") {
  VariantGallery("Glass panel", axis: "backdrop sampling on / off") {
    Variant("kinoGlass (sampling)") {
      GlassSample()
        .kinoGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    Variant("substitute (reduce transparency,\nincreased contrast, A12 Apple TV)") {
      GlassSample()
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
          .fill(Color.KinoPub.glassSubstitute))
    }
  }
  .preferredColorScheme(.dark)
}

private struct GlassSample: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Filters")
        .font(.headline)
        .foregroundStyle(Color.KinoPub.text)
      Text("4K · HDR · 2024")
        .font(.subheadline)
        .foregroundStyle(Color.KinoPub.subtitle)
    }
    .padding(24)
    .frame(width: 260, alignment: .leading)
  }
}
#endif
