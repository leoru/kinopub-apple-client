//
//  SeasonsRailView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Season tabs over a horizontally scrolling rail of episode stills, the way the
/// Apple TV app presents a series. Opens on the season the user is part-way through.
///
/// Episode cards are the same landscape `MediaCardView` Continue Watching uses.
struct SeasonsRailView: View {

  let seasons: [Season]
  let linkProvider: NavigationLinkProvider
  /// Filled into every episode handed to the player, so its transport bar can show the
  /// series name rather than just the episode's own title.
  let seriesTitle: String
  var onHide: ((Episode, Season) -> Void)?
  var onToggleWatched: ((Episode, Season) -> Void)?

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
          let card = Self.card(for: episode, in: season)
          NavigationLink(value: linkProvider.player(for: filled(episode, in: season))) {
            MediaCardView(card: card, caption: Self.cardCaption)
          }
#if os(tvOS)
          .buttonStyle(.borderless)
#else
          .buttonStyle(MediaCardButtonStyle())
#endif
          .modifier(MediaCardContextMenuModifier(actions: contextActions(for: card, episode: episode, season: season)))
        }
      }
      .padding(.horizontal, Self.horizontalInset)
      .padding(.vertical, Self.focusPadding)
    }
    // Rebuild the rail when the season changes so it scrolls back to the start.
    .id(season.id)
  }

  private func contextActions(for card: MediaCard, episode: Episode, season: Season) -> [MediaCardContextAction] {
    MediaCardContextMenus.actions(
      for: card,
      includeGoToTitle: false,
      onHide: { onHide?(episode, season) },
      onToggleWatched: { onToggleWatched?(episode, season) },
      onGoToTitle: {}
    )
  }

  /// Episodes arrive without their season/media context, which playback needs.
  private func filled(_ episode: Episode, in season: Season) -> Episode {
    episode.seasonNumber = season.number
    episode.mediaId = season.mediaId
    episode.seriesTitle = seriesTitle
    return episode
  }

  /// Same landscape card Continue Watching builds — still, overlay, resume bar.
  private static func card(for episode: Episode, in season: Season) -> MediaCard {
    let progress: Double? = {
      guard episode.watched == 0, episode.duration > 0, episode.watching.time > 0 else { return nil }
      return min(Double(episode.watching.time) / Double(episode.duration), 1.0)
    }()

    var labelParts: [String] = ["\("Episode".localized) \(episode.number)"]
    let minutes = episode.duration / 60
    if minutes > 0 {
      labelParts.append("\(minutes) min")
    }

    return MediaCard(id: episode.id,
                     posterURL: episode.thumbnail,
                     title: episode.fixedTitle,
                     progress: progress,
                     landscapeImageURL: episode.thumbnail,
                     overlayLabel: labelParts.joined(separator: " · "),
                     itemID: season.mediaId ?? episode.mediaId,
                     video: episode.number,
                     season: season.number,
                     mediaID: episode.id,
                     isWatched: episode.watched > 0,
                     isSeries: true)
  }

#if os(tvOS)
  /// Match home rows: name under the still only while focused, so the rail doesn't reflow.
  static let cardCaption: MediaCardCaption = .onFocus
  static let horizontalInset: CGFloat = 80
  static let cardSpacing: CGFloat = 36
  static let tabSpacing: CGFloat = 16
  static let focusPadding: CGFloat = 32
  static let tabFont: Font = .system(size: 28, weight: .semibold)
#else
  static let cardCaption: MediaCardCaption = .always
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
