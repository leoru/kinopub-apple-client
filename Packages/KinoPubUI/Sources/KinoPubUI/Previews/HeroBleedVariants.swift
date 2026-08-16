//
//  HeroBleedVariants.swift
//  KinoPubUI
//
//  Isolated gallery for MediaItem hero backdrop treatments.
//  Axis: how art softens into chrome / past the hard 16:9 crop.
//  Delete once one treatment is locked into MediaItemHeroView.
//
//  Note: `backgroundExtensionEffect` stays banned as *page / sidebar / nav*
//  chrome (see materials-blur-and-chrome.md). Variant D uses it the way the
//  nilcoalescing card pattern does — blur bleed of a contained image into its
//  own safeAreaInset, not under a TabView sidebar.
//

#if DEBUG
import SwiftUI

#Preview("Hero bleed — blur stack") {
  ScrollView(.horizontal) {
    VariantGallery(
      "MediaItem hero backdrop",
      axis: "legibility wash / art extension past the 16:9 crop"
    ) {
      Variant("A · private variableBlur\n(foot only, no bleed)") {
        HeroBleedHarness {
          HeroBleedPrivateBlur()
        }
      }
      Variant("B · system material + mask\n(community pattern)") {
        HeroBleedHarness {
          HeroBleedMaterialWash()
        }
      }
      Variant("C · art bleed above\n(manual duplicate + blur)") {
        HeroBleedHarness(showsBleedZone: true) {
          HeroBleedArtExtension()
        }
      }
      Variant("D · backgroundExtensionEffect\n(system blur bleed)") {
        HeroBleedSystemExtension()
      }
    }
  }
  .preferredColorScheme(.dark)
}

// MARK: - Harness (A–C)

/// Fixed 16:9 stage plus optional space *above* the crop so bleed is visible.
private struct HeroBleedHarness<Content: View>: View {
  var showsBleedZone: Bool = false
  @ViewBuilder var content: () -> Content

  private let stageWidth: CGFloat = 420
  private let bleedHeight: CGFloat = 72

  var body: some View {
    VStack(spacing: 0) {
      if showsBleedZone {
        Color.KinoPub.background
          .frame(height: bleedHeight)
          .overlay(alignment: .bottom) {
            Text("↑ chrome / safe area")
              .font(.caption2)
              .foregroundStyle(Color.KinoPub.subtitle.opacity(0.7))
              .padding(.bottom, 6)
          }
      }

      content()
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(width: stageWidth)
        .clipped()
        .overlay(alignment: .bottomLeading) {
          HeroBleedChrome()
        }
    }
    .frame(width: stageWidth)
    .background(Color.KinoPub.background)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
    }
  }
}

private struct HeroBleedChrome: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Паук-Нуар")
        .font(.title3.bold())
        .foregroundStyle(.white)
      Text("2026 · Crime · Drama")
        .font(.caption)
        .foregroundStyle(.white.opacity(0.85))
    }
    .shadow(color: .black.opacity(0.8), radius: 16, y: 4)
    .padding(16)
  }
}

private enum HeroBleedSample {
  static let wideURL = URL(string: "https://m.staticpop.net/poster/item/wide/581.jpg")!
  static let stageWidth: CGFloat = 420
  static let artHeight: CGFloat = 420 * 9 / 16
  /// Zone above the sharp crop — where D's system extension should paint.
  static let topInset: CGFloat = 72
}

private var sampleArt: some View {
  CachedRemoteImage(
    url: HeroBleedSample.wideURL,
    contentMode: .fill,
    placeholder: { Color.KinoPub.placeholder },
    failure: { Color.KinoPub.placeholder }
  )
}

// MARK: - A · Private variableBlur (shipping helper)

/// Foot blur only — same ProgressiveBlur path as Home banners (disabled on Mac there).
private struct HeroBleedPrivateBlur: View {
  var body: some View {
    ZStack(alignment: .bottom) {
      sampleArt

#if os(macOS)
      // Mirrors HomeBannerCardView: AppKit variableBlur often reads as a frosted plate.
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0.4),
          .init(color: .black.opacity(0.55), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
#else
      ProgressiveBlur(startPoint: 0.42, maxRadius: 36)
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0.45),
          .init(color: .black.opacity(0.35), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
#endif
    }
  }
}

// MARK: - B · System material + mask (community)

/// What kinopub-apple-client-community ships in `HeroBackdrop`: public material,
/// masked soft — opacity and Mac compose correctly because the system owns sampling.
private struct HeroBleedMaterialWash: View {
  var body: some View {
    ZStack(alignment: .bottom) {
      sampleArt

      Rectangle()
        .fill(.ultraThinMaterial)
        .frame(maxHeight: .infinity)
        .mask(
          LinearGradient(
            colors: [.clear, .clear, .black],
            startPoint: .top,
            endPoint: .bottom
          )
        )

      LinearGradient(
        stops: [
          .init(color: Color.KinoPub.background.opacity(0), location: 0.45),
          .init(color: Color.KinoPub.background.opacity(0.55), location: 0.82),
          .init(color: Color.KinoPub.background, location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
  }
}

// MARK: - C · Art extension above the crop

/// Manual bleed past the hard 16:9 edge. A second copy of the same still is
/// scaled up, blurred, and faded so colour continues into the zone above the hero.
private struct HeroBleedArtExtension: View {
  private let bleedHeight: CGFloat = HeroBleedSample.topInset

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height

      ZStack(alignment: .top) {
        sampleArt
          .frame(width: w, height: h)
          .scaleEffect(1.35, anchor: .top)
          .blur(radius: 28, opaque: true)
          .opacity(0.85)
          .mask(
            LinearGradient(
              stops: [
                .init(color: .black.opacity(0.55), location: 0),
                .init(color: .black.opacity(0.2), location: 0.35),
                .init(color: .clear, location: 0.7)
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: w, height: bleedHeight + 40, alignment: .top)
          .offset(y: -bleedHeight)
          .allowsHitTesting(false)

        sampleArt
          .frame(width: w, height: h)
          .clipped()

        Rectangle()
          .fill(.ultraThinMaterial)
          .mask(
            LinearGradient(
              colors: [.clear, .black.opacity(0.15), .black],
              startPoint: .top,
              endPoint: .bottom
            )
          )

        LinearGradient(
          stops: [
            .init(color: .clear, location: 0.55),
            .init(color: Color.KinoPub.background.opacity(0.75), location: 0.92),
            .init(color: Color.KinoPub.background, location: 1)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      }
      .frame(width: w, height: h)
      .padding(.top, bleedHeight)
      .offset(y: -bleedHeight)
    }
  }
}

// MARK: - D · System backgroundExtensionEffect (card blur bleed)

/// nilcoalescing / WWDC25 card pattern: the system mirrors+blurs the still into
/// *this view's* safe-area insets — not under the app sidebar.
///
/// Top inset ≈ "chrome above the crop"; bottom inset carries the title on the
/// extended wash. Clip is applied *after* the effect so the bleed stays inside
/// the card.
private struct HeroBleedSystemExtension: View {
  var body: some View {
    sampleArt
      .frame(width: HeroBleedSample.stageWidth, height: HeroBleedSample.artHeight)
      .clipped()
      .backgroundExtensionEffect()
      .safeAreaInset(edge: .top, spacing: 0) {
        Color.clear
          .frame(height: HeroBleedSample.topInset)
          .overlay(alignment: .bottom) {
            Text("↑ system extension")
              .font(.caption2)
              .foregroundStyle(Color.KinoPub.subtitle.opacity(0.85))
              .padding(.bottom, 6)
          }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        HeroBleedChrome()
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            LinearGradient(
              colors: [.black.opacity(0.55), .clear],
              startPoint: .bottom,
              endPoint: .top
            )
          )
      }
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
      }
      .frame(width: HeroBleedSample.stageWidth)
  }
}
#endif
