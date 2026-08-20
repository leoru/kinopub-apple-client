//
//  NativeChromePreviews.swift
//  KinoPubUI
//
//  One canvas for badges, ratings, headers, cards — open this file in the canvas
//  without building the full app.
//

import SwiftUI
import KinoPubBackend

#if DEBUG

enum PreviewSample {
  static let posterURL = "https://m.staticpop.net/poster/item/big/581.jpg"
  static let backdropURL = "https://m.staticpop.net/poster/item/wide/581.jpg"
  static let landscapeURL = "https://m.staticpop.net/poster/item/wide/581.jpg"

  static func posterCard(
    title: String = "Стражи Галактики. Часть 3",
    subtitle: String = "Guardians of the Galaxy Vol. 3",
    imdb: Double? = 8.1,
    kp: Double? = 8.3,
    progress: Double? = nil,
    badge: String? = "+2",
    is4K: Bool = true,
    isHDR: Bool = true,
    isWatched: Bool = false
  ) -> MediaCard {
    MediaCard(
      id: 581,
      posterURL: posterURL,
      title: title,
      subtitle: subtitle,
      imdbRating: imdb,
      kinopoiskRating: kp,
      progress: progress,
      badge: badge,
      backdropURL: backdropURL,
      isWatched: isWatched,
      is4K: is4K,
      isHDR: isHDR
    )
  }

  static var landscapeCard: MediaCard {
    MediaCard(
      id: 582,
      posterURL: posterURL,
      title: "Очень длинное название серии которое должно бежать маркви",
      subtitle: nil,
      imdbRating: 7.4,
      kinopoiskRating: 7.1,
      progress: 0.62,
      landscapeImageURL: landscapeURL,
      overlayLabel: "S2, E5 · 42 min",
      isSeries: true
    )
  }

  static var bannerCard: MediaCard {
    MediaCard(
      id: 583,
      posterURL: posterURL,
      title: "Паук-Нуар",
      subtitle: "Spider-Noir",
      imdbRating: 7.8,
      kinopoiskRating: 7.5,
      backdropURL: backdropURL,
      is4K: true,
      isHDR: false
    )
  }

  static var fullBadges: MediaCapabilityBadges {
    MediaCapabilityBadges(
      is4K: true,
      isHD: false,
      isHDR: true,
      is3D: true,
      ageRating: "16+",
      hasClosedCaptions: true,
      languages: ["RU", "EN"],
      audioChannelHint: "DD"
    )
  }
}

#Preview("Badges — poster vs detail") {
  VStack(alignment: .leading, spacing: 24) {
    Text("Poster chips (4K / HDR only)")
      .font(.caption)
      .foregroundStyle(.secondary)
    MediaCapabilityBadgesView(badges: PreviewSample.fullBadges, mode: .poster)

    Text("Detail chips (full set)")
      .font(.caption)
      .foregroundStyle(.secondary)
    MediaCapabilityBadgesView(badges: PreviewSample.fullBadges, mode: .detail)

    Text("HD only")
      .font(.caption)
      .foregroundStyle(.secondary)
    MediaCapabilityBadgesView(
      badges: MediaCapabilityBadges(isHD: true, ageRating: "12+"),
      mode: .detail
    )
  }
  .padding(32)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Ratings") {
  VStack(alignment: .leading, spacing: 16) {
    ForEach([9.1, 7.4, 6.2, 4.8], id: \.self) { score in
      if let rating = Rating(imdb: score, kinopoisk: score) {
        HStack(spacing: 16) {
          RatingBadgeView(rating: rating)
          AggregateRatingLabel(rating: rating)
          MediaScoresView(imdb: score, kinopoisk: score - 0.2)
        }
      }
    }
  }
  .padding(32)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Section headers") {
  VStack(alignment: .leading, spacing: 20) {
    SectionHeader("Continue Watching", count: "12", showsChevron: true)
      .environment(\.cardFocused, true)
    SectionHeader("Hot Films", count: "48", showsChevron: false)
    SectionHeader("Cast & Crew", leadingInset: 24)
  }
  .padding(32)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  .background(Color.KinoPub.background)
  .preferredColorScheme(.dark)
}

#Preview("Marquee") {
  VStack(alignment: .leading, spacing: 12) {
    Text("Narrow frame — focus in canvas to scroll")
      .font(.caption)
      .foregroundStyle(.secondary)
    MarqueeText(
      "Стражи Галактики. Часть 3 / Guardians of the Galaxy Vol. 3 — очень длинный заголовок",
      font: TypeScale.cardTitle
    )
    .frame(width: 180)
    .border(Color.white.opacity(0.2))
  }
  .padding(32)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Poster lockups") {
  HStack(alignment: .top, spacing: 24) {
    MediaCardView(card: PreviewSample.posterCard(), caption: .always)
      .frame(width: 200)

    MediaCardView(
      card: PreviewSample.posterCard(
        badge: nil,
        is4K: true,
        isHDR: false,
        isWatched: true
      ),
      caption: .always
    )
    .frame(width: 200)

    MediaCardView(
      card: PreviewSample.posterCard(
        imdb: 5.2,
        kp: 5.0,
        progress: 0.35,
        badge: nil,
        is4K: false,
        isHDR: false
      ),
      caption: .always
    )
    .frame(width: 200)
  }
  .padding(32)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Landscape + banner") {
  VStack(alignment: .leading, spacing: 28) {
    MediaCardView(card: PreviewSample.landscapeCard, caption: .always)
      .frame(width: 360)

    HomeBannerCardView(card: PreviewSample.bannerCard)
      .frame(width: 720)
  }
  .padding(32)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Image loading cue") {
  VStack(alignment: .leading, spacing: 16) {
    Text("No title available — neutral glyph")
      .font(.caption)
      .foregroundStyle(.secondary)
    ZStack {
      Color.black.opacity(0.45)
      RemoteImageLoadingCue(delay: .milliseconds(100))
    }
    .frame(width: 320, height: 180)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

    Text("Title known at call site — shown as text")
      .font(.caption)
      .foregroundStyle(.secondary)
    ZStack {
      Color.black.opacity(0.45)
      RemoteImageLoadingCue(
        title: PreviewSample.posterCard().title,
        delay: .milliseconds(100)
      )
    }
    .frame(width: 320, height: 180)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
  .padding(32)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Action pills") {
  HStack(spacing: MediaActionMetrics.rowSpacing) {
    Button {} label: {
      HStack(spacing: MediaActionMetrics.contentSpacing) {
        Image(systemName: "play.fill")
        Text("Play")
          .font(MediaActionMetrics.labelFont)
      }
    }
    .mediaActionPlayPillStyle()

    Button {} label: {
      Text("Watchlist")
        .font(MediaActionMetrics.labelFont)
    }
    .mediaActionPillStyle()

    Button {} label: {
      Image(systemName: "checkmark")
            .font(MediaActionMetrics.labelFont)
//        .mediaActionIconFont(size: MediaActionMetrics.circleIconPointSize, weight: .semibold)
    }
    .mediaActionPlayPillStyle()

//    .mediaActionCircleStyle()
  }
  .padding(32)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  .background(Color.black)
  .preferredColorScheme(.dark)
}

#endif
