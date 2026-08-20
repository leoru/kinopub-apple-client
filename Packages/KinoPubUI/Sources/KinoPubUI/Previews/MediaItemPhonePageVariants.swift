//
//  MediaItemPhonePageVariants.swift
//  KinoPubUI
//
//  iPhone detail page layouts (not Home banners): wide still as backdrop,
//  poster above the action row. Open each preview on an iPhone canvas.
//  Delete once one treatment is locked into MediaItemHeroView / MediaItemView.
//

#if DEBUG
import SwiftUI

#Preview("A · Odyssey stack") {
  PhonePageOdyssey()
    .preferredColorScheme(.dark)
}

#Preview("B · Title on art") {
  PhonePageTitleOnArt()
    .preferredColorScheme(.dark)
}

#Preview("C · System extension") {
  PhonePageSystemExtension()
    .preferredColorScheme(.dark)
}

// MARK: - Sample

private enum PhonePageSample {
  static let wide = URL(string: "https://m.staticpop.net/poster/item/wide/581.jpg")!
  static let poster = URL(string: "https://m.staticpop.net/poster/item/big/581.jpg")!
  static let titleLogo = URL(
    string: "https://kinopub-tmdb-proxy.traneblow1nd.workers.dev/t/p/w500/66NvmhvjxA7aWQ1TxTV5qBpOZ0k.png"
  )!
  static let title = "Паук-Нуар"
  static let meta = "2026 · Crime · Drama"
  static let genres = "Crime, Drama, Mystery"
  static let plot =
    "A noir detective tangled in a web of corporate intrigue. When the city turns "
    + "against him, every ally becomes a suspect."
  static let rating = Rating(imdb: 7.8, kinopoisk: 7.5)!
  static let horizontalInset: CGFloat = 20
  static let posterWidth: CGFloat = 148
}

// MARK: - Shared atoms

private struct PhoneWideArt: View {
  var body: some View {
    CachedRemoteImage(
      url: PhonePageSample.wide,
      contentMode: .fill,
      placeholder: { Color.KinoPub.placeholder },
      failure: { Color.KinoPub.placeholder }
    )
  }
}

private struct PhonePoster: View {
  var width: CGFloat = PhonePageSample.posterWidth

  var body: some View {
    CachedRemoteImage(
      url: PhonePageSample.poster,
      contentMode: .fill,
      placeholder: { Color.KinoPub.placeholder },
      failure: { Color.KinoPub.placeholder }
    )
    .aspectRatio(CardAspect.poster.ratio, contentMode: .fit)
    .frame(width: width)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(alignment: .topLeading) {
      RatingBadgeView(rating: PhonePageSample.rating)
        .padding(6)
    }
    .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
  }
}

private struct PhoneNavChrome: View {
  var body: some View {
    HStack {
      circleGlyph("chevron.left")
      Spacer()
      HStack(spacing: 10) {
        circleGlyph("square.and.arrow.up")
        circleGlyph("ellipsis")
      }
    }
    .padding(.horizontal, PhonePageSample.horizontalInset)
    .padding(.top, 8)
  }

  private func circleGlyph(_ name: String) -> some View {
    Image(systemName: name)
      .font(.body.weight(.semibold))
      .foregroundStyle(.white)
      .frame(width: 36, height: 36)
      .background(.ultraThinMaterial, in: Circle())
  }
}

private struct PhoneMetaBlock: View {
  var centered: Bool = true
  var showGenres: Bool = true
  var useTitleLogo: Bool = false

  var body: some View {
    VStack(alignment: centered ? .center : .leading, spacing: 6) {
      if useTitleLogo {
        PhoneTitleLogo()
      } else {
        Text(PhonePageSample.title)
          .font(TypeScale.heroTitle)
          .foregroundStyle(Color.KinoPub.text)
          .multilineTextAlignment(centered ? .center : .leading)
      }

      Text(PhonePageSample.meta)
        .font(TypeScale.detailBody)
        .foregroundStyle(Color.KinoPub.subtitle)

      if showGenres {
        Text(PhonePageSample.genres)
          .font(TypeScale.detailBody)
          .foregroundStyle(Color.KinoPub.subtitle.opacity(0.85))
      }
    }
    .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
  }
}

/// TMDB title treatment — falls back to lettered title if the logo fails.
private struct PhoneTitleLogo: View {
  var maxHeight: CGFloat = 72

  var body: some View {
    ArtworkImage(url: PhonePageSample.titleLogo) { phase in
      switch phase {
      case .success(let image):
        image
          .resizable()
          .scaledToFit()
          .frame(maxWidth: 280, maxHeight: maxHeight)
          .shadow(color: .black.opacity(0.55), radius: 12, y: 4)
      case .failure:
        Text(PhonePageSample.title)
          .font(TypeScale.heroTitle)
          .foregroundStyle(Color.KinoPub.text)
      case .empty:
        ProgressView()
          .tint(.white)
          .frame(height: maxHeight * 0.6)
      }
    }
  }
}

/// Full-width primary CTA. Do **not** use `mediaActionPlayPillStyle` here: that
/// style adds horizontal padding *outside* a `maxWidth: .infinity` label and
/// overflows the content column on phone.
private struct PhonePlayPill: View {
  var label: String = "Play"
  var showProgress: Bool = false

  var body: some View {
    Button {} label: {
      HStack(spacing: MediaActionMetrics.contentSpacing) {
        Image(systemName: "play.fill")
              .font(MediaActionMetrics.labelFont)

//          .mediaActionIconFont(size: MediaActionMetrics.iconPointSize, weight: .semibold)
        if showProgress {
          MediaActionProgressTrack(progress: 0.35)
        }
        Text(label)
          .font(MediaActionMetrics.labelFont)
          .lineLimit(1)
      }
      .foregroundStyle(.black)
      .frame(maxWidth: .infinity)
//      .frame(height: MediaActionMetrics.buttonHeight)
      .background(Capsule(style: .continuous).fill(.white))
    }
    .buttonStyle(.plain)
  }
}

private struct PhoneCircleRow: View {
  var body: some View {
    HStack(spacing: MediaActionMetrics.rowSpacing) {
      circle("plus")
      circle("bookmark")
      circle("checkmark")
      circle("film")
    }
  }

  private func circle(_ systemName: String) -> some View {
    Button {} label: {
      Image(systemName: systemName)
            .font(MediaActionMetrics.labelFont)

//        .mediaActionIconFont(size: MediaActionMetrics.circleIconPointSize, weight: .semibold)
    }
    .mediaActionPillStyle()
  }
}

private struct PhonePlot: View {
  var body: some View {
    Text(PhonePageSample.plot)
      .font(TypeScale.detailBody)
      .foregroundStyle(Color.KinoPub.text)
      .multilineTextAlignment(.leading)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct PhoneGradientFoot: View {
  var body: some View {
    LinearGradient(
      stops: [
        .init(color: .clear, location: 0.35),
        .init(color: Color.KinoPub.background.opacity(0.55), location: 0.7),
        .init(color: Color.KinoPub.background, location: 1)
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }
}

private struct PhoneVariableWash: View {
  var body: some View {
    ZStack {
#if os(macOS)
      Rectangle()
        .fill(.ultraThinMaterial)
        .mask(
          LinearGradient(
            colors: [.clear, .clear, .black],
            startPoint: .top,
            endPoint: .bottom
          )
        )
#else
      ProgressiveBlur(startPoint: 0.38, maxRadius: 40)
#endif
      PhoneGradientFoot()
    }
  }
}

// MARK: - A · Odyssey

private struct PhonePageOdyssey: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        ZStack(alignment: .top) {
          PhoneWideArt()
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .clipped()
            .overlay(PhoneGradientFoot())

          PhoneNavChrome()
        }

        PhonePoster()
          .offset(y: -72)
          .padding(.bottom, -56)

        VStack(spacing: 16) {
          PhoneMetaBlock(useTitleLogo: true)
          PhonePlayPill(label: "Play")
          PhoneCircleRow()
          PhonePlot()
            .padding(.top, 8)
        }
        .padding(.horizontal, PhonePageSample.horizontalInset)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
      }
    }
    .scrollIndicators(.hidden)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.KinoPub.background)
    .ignoresSafeArea(edges: .top)
  }
}

// MARK: - B · Title on art

private struct PhonePageTitleOnArt: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        ZStack(alignment: .bottom) {
          PhoneWideArt()
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .clipped()
            .overlay(PhoneVariableWash())

          VStack(spacing: 0) {
            PhoneNavChrome()
            Spacer(minLength: 0)
            VStack(spacing: 10) {
              PhoneTitleLogo(maxHeight: 64)

              HStack(spacing: 10) {
                RatingBadgeView(rating: PhonePageSample.rating)
                Text(PhonePageSample.meta)
                  .font(TypeScale.detailBody)
                  .foregroundStyle(.white.opacity(0.9))
              }

              Text(PhonePageSample.genres)
                .font(TypeScale.detailBody)
                .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, PhonePageSample.horizontalInset)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        VStack(spacing: 16) {
          PhonePoster(width: 120)
          PhonePlayPill(label: "Play movie")
          PhoneCircleRow()
          PhonePlot()
            .padding(.top, 4)
        }
        .padding(.horizontal, PhonePageSample.horizontalInset)
        .padding(.top, 8)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
      }
    }
    .scrollIndicators(.hidden)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.KinoPub.background)
    .ignoresSafeArea(edges: .top)
  }
}

// MARK: - C · System extension

private struct PhonePageSystemExtension: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        ZStack(alignment: .top) {
          PhoneWideArt()
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipped()
            .backgroundExtensionEffect()
            .safeAreaInset(edge: .bottom, spacing: 0) {
              Color.clear.frame(height: 88)
            }
            .overlay(alignment: .bottom) {
              PhoneGradientFoot()
                .frame(height: 160)
            }
            .clipped()

          PhoneNavChrome()
        }

        VStack(spacing: 16) {
          PhonePoster()
            .offset(y: -40)
            .padding(.bottom, -24)

          PhoneMetaBlock(useTitleLogo: true)

          PhonePlayPill(label: "Resume · 39 min", showProgress: true)

          PhoneCircleRow()

          PhonePlot()
            .padding(.top, 4)
        }
        .padding(.horizontal, PhonePageSample.horizontalInset)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
      }
    }
    .scrollIndicators(.hidden)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.KinoPub.background)
    .ignoresSafeArea(edges: .top)
  }
}
#endif
