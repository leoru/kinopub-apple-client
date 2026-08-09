//
//  HomeBannerCardView.swift
//  KinoPubUI
//
//  Contained 16:9 Home featured card: wide backdrop, inset vertical poster,
//  titles + ratings. No CTAs for v1. Static art only — ProgressiveBlur is OK.
//

import SwiftUI

/// One contained featured banner for the Home shelf.
public struct HomeBannerCardView: View {
  private let card: MediaCard

  public init(card: MediaCard) {
    self.card = card
  }

  public var body: some View {
    Color.clear
      .aspectRatio(CardAspect.landscape.ratio, contentMode: .fit)
      .overlay {
        GeometryReader { geo in
          content(in: geo.size)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
  }

  private func content(in size: CGSize) -> some View {
    let posterHeight = min(size.height * 0.72, size.height - Self.contentPadding * 2)

    return ZStack(alignment: .bottomLeading) {
      backdrop(size: size)

#if os(macOS)
      // AppKit variable-blur samples unreliably and reads as a frosted plate over
      // the wide still. A plain scrim keeps the 16:9 art visible on Mac.
#else
      ProgressiveBlur(startPoint: 0.42, maxRadius: 36)
#endif

      LinearGradient(
        stops: [
          .init(color: .clear, location: 0.35),
          .init(color: .black.opacity(0.45), location: 0.72),
          .init(color: .black.opacity(0.7), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
      )

      HStack(alignment: .bottom, spacing: Self.infoSpacing) {
        poster(height: posterHeight)

        VStack(alignment: .leading, spacing: Self.titleSpacing) {
          Text(card.title)
            .font(Self.titleFont)
            .foregroundStyle(.white)
            .lineLimit(1)

          if let subtitle = card.subtitle, !subtitle.isEmpty, subtitle != card.title {
            Text(subtitle)
              .font(Self.subtitleFont)
              .foregroundStyle(.white.opacity(0.85))
              .lineLimit(1)
          }

          // Detailed IMDb / KP scores stay beside the copy; the poster carries the
          // compact aggregate badge so the still reads like a catalog lockup.
          if card.imdbRating != nil || card.kinopoiskRating != nil {
            MediaScoresView(imdb: card.imdbRating, kinopoisk: card.kinopoiskRating)
              .font(Self.scoreFont)
              .foregroundStyle(.white.opacity(0.92))
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(Self.contentPadding)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(card.title))
    .accessibilityValue(Text(bannerAccessibilityValue))
  }

  private var bannerAccessibilityValue: String {
    var parts: [String] = []
    if let subtitle = card.subtitle, !subtitle.isEmpty, subtitle != card.title {
      parts.append(subtitle)
    }
    if let rating = card.rating {
      parts.append("Rating \(rating.formatted)")
    }
    return parts.joined(separator: ", ")
  }

  /// Prefer API `wide`, then derived `/wide/`, then `big`/`medium` as a fill.
  private func backdrop(size: CGSize) -> some View {
    let candidates = Self.backdropCandidates(for: card)
    return FallbackRemoteImage(urls: candidates, contentMode: .fill)
      .frame(width: size.width, height: size.height)
      .clipped()
      .onAppear {
        // Visible in Console: filter subsystem com.soda.kinopub category Artwork
        #if DEBUG
        let list = candidates.map(\.absoluteString).joined(separator: " | ")
        print("[Artwork] banner id=\(card.id) candidates=\(list)")
        #endif
      }
  }

  private static func backdropCandidates(for card: MediaCard) -> [URL] {
    var seen = Set<String>()
    var urls: [URL] = []
    // Order: API/derived wide → big (same id) → medium poster. Catalogue `/wide/`
    // often 404s; detail pages get a real wide — same title, different payload.
    var strings: [String] = []
    if let backdrop = card.backdropURL, !backdrop.isEmpty {
      strings.append(backdrop)
      strings.append(contentsOf: Self.siblingSizes(of: backdrop))
    }
    strings.append(contentsOf: Self.siblingSizes(of: card.posterURL))
    if !card.posterURL.isEmpty {
      strings.append(card.posterURL)
    }
    for raw in strings where seen.insert(raw).inserted {
      guard let url = URL(string: raw) else { continue }
      urls.append(url)
    }
    return urls
  }

  /// `/item/{small|medium|big|wide}/` siblings for the same poster id.
  private static func siblingSizes(of url: String) -> [String] {
    guard url.contains("/item/") else { return [] }
    let sizes = ["wide", "big", "medium", "small"]
    return sizes.compactMap { size -> String? in
      var next = url
      for from in sizes {
        next = next.replacingOccurrences(of: "/item/\(from)/", with: "/item/\(size)/")
      }
      return next == url ? nil : next
    }
  }

  private func poster(height: CGFloat) -> some View {
    CachedRemoteImage(
      url: URL(string: card.posterURL),
      contentMode: .fill,
      placeholder: {
        ZStack {
          Color.black.opacity(0.25)
          RemoteImageLoadingCue(title: card.title, delay: .milliseconds(250))
        }
      },
      failure: {
        Color.black.opacity(0.35)
      }
    )
    .aspectRatio(CardAspect.poster.ratio, contentMode: .fit)
    .frame(height: height)
    .overlay(alignment: .topLeading) {
      if RatingFeature.combinedEnabled, let rating = card.rating {
        RatingBadgeView(rating: rating)
          .padding(4)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: Self.posterCornerRadius, style: .continuous))
#if !os(tvOS)
    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
#endif
  }

#if os(tvOS)
  static let cornerRadius: CGFloat = 20
  static let posterCornerRadius: CGFloat = 10
  static let contentPadding: CGFloat = 28
  static let infoSpacing: CGFloat = 24
  static let titleSpacing: CGFloat = 8
  static let titleFont: Font = .title2.bold()
  static let subtitleFont: Font = .title3
  static let scoreFont: Font = .callout.weight(.medium)
#else
  static let cornerRadius: CGFloat = 14
  static let posterCornerRadius: CGFloat = 8
  static let contentPadding: CGFloat = 14
  static let infoSpacing: CGFloat = 14
  static let titleSpacing: CGFloat = 4
  static let titleFont: Font = .headline.bold()
  static let subtitleFont: Font = .subheadline
  static let scoreFont: Font = .caption.weight(.medium)
#endif
}

#Preview("Banner with poster rating") {
  HomeBannerCardView(
    card: MediaCard(
      id: 1,
      posterURL: "https://m.staticpop.net/poster/item/big/581.jpg",
      title: "Паук-Нуар",
      subtitle: "Spider-Noir",
      imdbRating: 7.8,
      kinopoiskRating: 7.5,
      backdropURL: "https://m.staticpop.net/poster/item/wide/581.jpg",
      is4K: true,
      isHDR: true
    )
  )
  .frame(width: 860)
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Banner loading art") {
  HomeBannerCardView(
    card: MediaCard(
      id: 2,
      posterURL: "",
      title: "Без арта — loading / failure",
      subtitle: "Empty URLs",
      imdbRating: 6.5,
      kinopoiskRating: 6.2,
      backdropURL: ""
    )
  )
  .frame(width: 860)
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
