//
//  SeasonsRailView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Season tabs over a horizontally scrolling rail of episode stills, the way the
/// Apple TV app presents a series. Opens on the season the user is part-way through.
struct SeasonsRailView: View {

  let seasons: [Season]
  let linkProvider: NavigationLinkProvider

  @State private var selectedSeasonID: Int?

  private var selectedSeason: Season? {
    seasons.first { $0.id == selectedSeasonID } ?? seasons.first
  }

  /// The first season with something left to watch, else the first.
  private var defaultSeason: Season? {
    seasons.first { season in
      season.episodes.contains { $0.watched == 0 }
    } ?? seasons.first
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if seasons.count > 1 {
        seasonTabs
      }

      if let season = selectedSeason {
        episodeRail(for: season)
      }
    }
    .onAppear {
      if selectedSeasonID == nil {
        selectedSeasonID = defaultSeason?.id
      }
    }
  }

  private var seasonTabs: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: Self.tabSpacing) {
        ForEach(seasons) { season in
          Button {
            selectedSeasonID = season.id
          } label: {
            Text(season.fixedTitle)
              .font(Self.tabFont)
          }
          .buttonStyle(SeasonTabButtonStyle(isSelected: season.id == selectedSeason?.id))
        }
      }
      .padding(.horizontal, Self.horizontalInset)
      .padding(.vertical, Self.focusPadding)
    }
  }

  private func episodeRail(for season: Season) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(alignment: .top, spacing: Self.cardSpacing) {
        ForEach(season.episodes) { episode in
          NavigationLink(value: linkProvider.player(for: filled(episode, in: season))) {
            EpisodeCardView(episode: episode)
          }
          .buttonStyle(EpisodeCardButtonStyle())
        }
      }
      .padding(.horizontal, Self.horizontalInset)
      .padding(.vertical, Self.focusPadding)
    }
    // Rebuild the rail when the season changes so it scrolls back to the start.
    .id(season.id)
  }

  /// Episodes arrive without their season/media context, which playback needs.
  private func filled(_ episode: Episode, in season: Season) -> Episode {
    episode.seasonNumber = season.number
    episode.mediaId = season.mediaId
    return episode
  }

#if os(tvOS)
  static let horizontalInset: CGFloat = 80
  static let cardSpacing: CGFloat = 32
  static let tabSpacing: CGFloat = 16
  static let focusPadding: CGFloat = 24
  static let tabFont: Font = .system(size: 28, weight: .semibold)
#else
  static let horizontalInset: CGFloat = 20
  static let cardSpacing: CGFloat = 16
  static let tabSpacing: CGFloat = 8
  static let focusPadding: CGFloat = 6
  static let tabFont: Font = .system(size: 16, weight: .semibold)
#endif
}

/// A season tab: filled when selected, outlined otherwise, and lifting on focus.
private struct SeasonTabButtonStyle: ButtonStyle {
  let isSelected: Bool

  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Tab(configuration: configuration, isSelected: isSelected)
  }

  private struct Tab: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
        .foregroundStyle(isSelected ? Color.black : Color.KinoPub.text)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
          Capsule().fill(isSelected ? Color.KinoPub.accent : Color.KinoPub.selectionBackground)
        )
        .overlay(
          Capsule().stroke(Color.KinoPub.accent, lineWidth: isFocused && !isSelected ? 3 : 0)
        )
        .scaleEffect(isFocused ? 1.06 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
  }
}

private struct EpisodeCardButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Card(configuration: configuration)
  }

  private struct Card: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
        .scaleEffect(isFocused ? 1.06 : (configuration.isPressed ? 0.98 : 1.0))
        .shadow(color: .black.opacity(isFocused ? 0.45 : 0), radius: 16, y: 8)
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }
  }
}

/// Still, episode number, title and runtime — plus a progress bar for part-watched.
private struct EpisodeCardView: View {
  let episode: Episode

  private var progress: Double? {
    // Watched episodes carry the checkmark; a full bar underneath it says nothing.
    guard episode.watched == 0, episode.duration > 0, episode.watching.time > 0 else { return nil }
    return min(Double(episode.watching.time) / Double(episode.duration), 1.0)
  }

  private var runtime: String {
    let minutes = episode.duration / 60
    return minutes > 0 ? "\(minutes) min" : ""
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ZStack(alignment: .bottom) {
        AsyncImage(url: URL(string: episode.thumbnail)) { image in
          image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
          Color.KinoPub.placeholder
        }
        .frame(width: Self.width, height: Self.imageHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

        if let progress {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Capsule().fill(Color.black.opacity(0.55))
              Capsule().fill(Color.KinoPub.accent).frame(width: geometry.size.width * progress)
            }
          }
          .frame(height: 5)
          .padding(.horizontal, 8)
          .padding(.bottom, 8)
        }
      }
      .overlay(alignment: .topTrailing) {
        if episode.watched > 0 {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.KinoPub.accent)
            .padding(8)
        }
      }

      VStack(alignment: .leading, spacing: 2) {
        Text("\("Episode".localized) \(episode.number)")
          .font(Self.captionFont)
          .foregroundStyle(Color.KinoPub.subtitle)
        Text(episode.fixedTitle)
          .font(Self.titleFont)
          .foregroundStyle(Color.KinoPub.text)
          .lineLimit(1)
        if !runtime.isEmpty {
          Text(runtime)
            .font(Self.captionFont)
            .foregroundStyle(Color.KinoPub.subtitle)
        }
      }
      .frame(width: Self.width, alignment: .leading)
    }
  }

#if os(tvOS)
  static let width: CGFloat = 420
  static let imageHeight: CGFloat = 236
  static let titleFont: Font = .system(size: 26, weight: .medium)
  static let captionFont: Font = .system(size: 22, weight: .regular)
#else
  static let width: CGFloat = 220
  static let imageHeight: CGFloat = 124
  static let titleFont: Font = .system(size: 15, weight: .medium)
  static let captionFont: Font = .system(size: 13, weight: .regular)
#endif
}
