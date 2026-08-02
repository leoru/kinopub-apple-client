//
//  MediaItemDetailSections.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubMetadata
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Ratings

/// Score tiles: our aggregate first, then one per source, then internal views.
/// Pointer platforms open the source page when a real URL exists; aggregate and
/// views tiles are display-only.
struct MediaItemRatingsSection: View {

  let mediaItem: MediaItem
  /// Hidden while the hero/trailer owns the page — same chrome gate as season tabs,
  /// so "Ratings" doesn't caption the wide art peeking under the hero.
  var showsHeader: Bool = true
  var onSectionFocused: (() -> Void)? = nil
  /// tvOS: when non-nil, the first tile accepts `.content` page entry focus.
  var pageEntryFocus: FocusState<MediaItemFocusTarget?>.Binding? = nil
  @Environment(\.openURL) private var openURL

  fileprivate struct Score: Identifiable {
    let id: String
    let logo: MediaScoreLogo.Source
    let value: Double
    let votes: Int?
  }

  private var aggregate: Rating? {
    Rating(imdb: mediaItem.imdbRating, kinopoisk: mediaItem.kinopoiskRating)
  }

  private var aggregateVotes: Int {
    [mediaItem.imdbVotes, mediaItem.kinopoiskVotes]
      .compactMap { $0 }
      .filter { $0 > 0 }
      .reduce(0, +)
  }

  private var scores: [Score] {
    var result: [Score] = []
    if let imdb = mediaItem.imdbRating, imdb > 0 {
      result.append(Score(id: "IMDb", logo: .imdb, value: imdb, votes: mediaItem.imdbVotes))
    }
    if let kp = mediaItem.kinopoiskRating, kp > 0 {
      result.append(Score(id: "Кинопоиск", logo: .kinopoisk, value: kp, votes: mediaItem.kinopoiskVotes))
    }
    return result
  }

  private var hasContent: Bool {
    aggregate != nil || !scores.isEmpty || mediaItem.views > 0
  }

  var body: some View {
    if hasContent {
      VStack(alignment: .leading, spacing: 12) {
        if showsHeader {
          MediaItemSectionHeader("Ratings")
            .transition(.opacity)
        }

        HStack(alignment: .top, spacing: Self.spacing) {
          if let aggregate {
            AggregateRatingTile(rating: aggregate,
                                votes: aggregateVotes,
                                onSectionFocused: onSectionFocused,
                                pageEntryFocus: pageEntryFocus)
          }
          ForEach(Array(scores.enumerated()), id: \.element.id) { index, score in
            RatingTile(score: score,
                       url: scoreURL(score),
                       openURL: openURL,
                       onSectionFocused: onSectionFocused,
                       pageEntryFocus: aggregate == nil && index == 0 ? pageEntryFocus : nil)
          }
          if mediaItem.views > 0 {
            ViewsRatingTile(views: mediaItem.views,
                            onSectionFocused: onSectionFocused,
                            pageEntryFocus: aggregate == nil && scores.isEmpty ? pageEntryFocus : nil)
          }
        }
        .padding(.horizontal, MediaItemLayout.horizontalInset)
      }
      .animation(.easeOut(duration: 0.35), value: showsHeader)
    }
  }

  private func scoreURL(_ score: Score) -> URL? {
#if os(tvOS)
    return nil
#else
    switch score.logo {
    case .imdb:
      guard let id = mediaItem.imdb, id > 0 else { return nil }
      return URL(string: "https://www.imdb.com/title/tt\(String(format: "%07d", id))/")
    case .kinopoisk:
      guard let id = mediaItem.kinopoisk, id > 0 else { return nil }
      let kind = mediaItem.isSeries ? "series" : "film"
      return URL(string: "https://www.kinopoisk.ru/\(kind)/\(id)/")
    }
#endif
  }

#if os(tvOS)
  static let spacing: CGFloat = 24
  static let tilePadding: CGFloat = 24
  static let iconSize: CGFloat = 48
  static let valueFont: Font = .system(size: 48, weight: .bold, design: .rounded)
  static let titleFont: Font = .system(size: 22, weight: .semibold)
  static let captionFont: Font = .system(size: 20, weight: .regular)
#else
  static let spacing: CGFloat = 12
  static let tilePadding: CGFloat = 14
  static let iconSize: CGFloat = 32
  static let valueFont: Font = .system(size: 32, weight: .semibold, design: .rounded)
  static let titleFont: Font = .system(size: 14, weight: .semibold)
  static let captionFont: Font = .system(size: 13, weight: .regular)
#endif
}

private struct AggregateRatingTile: View {
  let rating: Rating
  let votes: Int
  var onSectionFocused: (() -> Void)? = nil
  var pageEntryFocus: FocusState<MediaItemFocusTarget?>.Binding? = nil
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    content
#if os(tvOS)
      // Focus stop for the rail — no press chrome, the tile is not an action.
      .focusable(true)
      .modifier(OptionalPageEntryFocus(binding: pageEntryFocus))
      .reportMediaItemSectionFocus(onSectionFocused)
#endif
  }

  private var content: some View {
    HStack(alignment: .center, spacing: 10) {
      ZStack {
        Circle()
          .fill(rating.tier.color)
        Image(systemName: "star.fill")
          .font(.system(size: MediaItemRatingsSection.iconSize * 0.58, weight: .semibold))
          .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
      }
      .frame(width: MediaItemRatingsSection.iconSize, height: MediaItemRatingsSection.iconSize)

      AggregateRatingLabel(rating: rating)

      VStack(alignment: .leading, spacing: 2) {
        Text("Rating")
          .font(MediaItemRatingsSection.titleFont)
          .foregroundStyle(Color.KinoPub.text)
        if votes > 0 {
          Text("\(votes.formatted(.number.grouping(.automatic))) \("votes".localized)")
            .font(MediaItemRatingsSection.captionFont)
            .foregroundStyle(Color.KinoPub.subtitle)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(MediaItemRatingsSection.tilePadding)
    .background(
      Color.KinoPub.selectionBackground.opacity(0.5),
      in: RoundedRectangle(cornerRadius: 14, style: .continuous)
    )
  }
}

private struct RatingTile: View {
  let score: MediaItemRatingsSection.Score
  let url: URL?
  let openURL: OpenURLAction
  var onSectionFocused: (() -> Void)? = nil
  var pageEntryFocus: FocusState<MediaItemFocusTarget?>.Binding? = nil
  @State private var isHovered = false

  private var isLink: Bool { url != nil }

  var body: some View {
    Button {
      if let url { openURL(url) }
    } label: {
      tileContent
    }
    .buttonStyle(RatingTileButtonStyle())
#if !os(tvOS)
    .onHover { isHovered = $0 }
    .pointingHandCursorOnHover(enabled: isLink)
#endif
#if os(tvOS)
    .modifier(OptionalPageEntryFocus(binding: pageEntryFocus))
    .reportMediaItemSectionFocus(onSectionFocused)
#endif
  }

  private var tileContent: some View {
    HStack(alignment: .center, spacing: 10) {
      MediaScoreLogo(score.logo, height: MediaItemRatingsSection.iconSize, style: .color)
        .frame(width: MediaItemRatingsSection.iconSize, height: MediaItemRatingsSection.iconSize)

      Text(String(format: "%.1f", score.value))
        .font(MediaItemRatingsSection.valueFont)
        // .monospacedDigit()
        .foregroundStyle(Color.KinoPub.subtitle)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(score.id)
            .font(MediaItemRatingsSection.titleFont)
            .foregroundStyle(Color.KinoPub.text)
          if isLink {
            Image(systemName: "arrow.up.right")
              .font(MediaItemRatingsSection.captionFont)
              .foregroundStyle(Color.KinoPub.subtitle)
          }
        }
        if let votes = score.votes, votes > 0 {
          Text("\(votes.formatted(.number.grouping(.automatic))) \("votes".localized)")
            .font(MediaItemRatingsSection.captionFont)
            .foregroundStyle(Color.KinoPub.subtitle)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(MediaItemRatingsSection.tilePadding)
    .background(
      Color.KinoPub.selectionBackground.opacity(isLink && isHovered ? 0.72 : 0.5),
      in: RoundedRectangle(cornerRadius: 14, style: .continuous)
    )
    .animation(.easeOut(duration: 0.15), value: isHovered)
  }
}

private struct ViewsRatingTile: View {
  let views: Int
  var onSectionFocused: (() -> Void)? = nil
  var pageEntryFocus: FocusState<MediaItemFocusTarget?>.Binding? = nil

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Text(views.formatted(.number.grouping(.automatic)))
        .font(MediaItemRatingsSection.valueFont)
        // .monospacedDigit()
        .foregroundStyle(Color.KinoPub.subtitle)

      VStack(alignment: .leading, spacing: 2) {
        Text("MediaItem_Views")
          .font(MediaItemRatingsSection.titleFont)
          .foregroundStyle(Color.KinoPub.text)
        Text("MediaItem_ViewsInternal")
          .font(MediaItemRatingsSection.captionFont)
          .foregroundStyle(Color.KinoPub.subtitle)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(MediaItemRatingsSection.tilePadding)
#if os(tvOS)
    .focusable(true)
    .modifier(OptionalPageEntryFocus(binding: pageEntryFocus))
    .reportMediaItemSectionFocus(onSectionFocused)
#endif
  }
}

/// Press feedback only — no hover shadow on the score tiles.
private struct RatingTileButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
      .animation(.spring(response: 0.15, dampingFraction: 0.9), value: configuration.isPressed)
  }
}

#if os(tvOS)
/// Kept for call-site compatibility; single-scroll detail no longer parks a
/// dedicated `.content` focus target after a slide flip.
private struct OptionalPageEntryFocus: ViewModifier {
  var binding: FocusState<MediaItemFocusTarget?>.Binding?

  func body(content: Content) -> some View {
    content
  }
}
#endif

// MARK: - Cast

/// Poster-shaped portraits. Photos and character names come from TMDB when the
/// metadata proxy is configured; otherwise initials and the role label.
///
/// Each one leads to that person's credits, which is also what makes the rail
/// reachable: a tvOS scroll view moves by focus, and portraits that were plain text
/// left everyone past the right edge of the screen unreachable.
struct MediaItemCastSection: View {

  let mediaItem: MediaItem
  let linkProvider: NavigationLinkProvider
  var externalMetadata: TitleMetadata = TitleMetadata()
  /// When false and the title has an IMDb id, skip the pushbr CDN fallback so we
  /// don't paint one URL and then swap it for TMDB (AsyncImage flash / initials blink).
  var externalMetadataLoaded: Bool = true
  var onSectionFocused: (() -> Void)? = nil

  /// Pushbr is a last resort after TMDB has had a chance — or immediately when
  /// there is no IMDb id and metadata will never arrive.
  private var allowPushbrFallback: Bool {
    externalMetadataLoaded || mediaItem.imdb == nil
  }

  private var people: [(person: MediaPerson, member: CastMember)] {
    let directors = TitleMetadata.enrich(
      names: mediaItem.directorNames,
      roleDepartment: "Directing",
      from: externalMetadata
    ).map {
      let photo = $0.photo
        ?? (allowPushbrFallback ? ActorImageProvider.photoURL(for: $0.name) : nil)
      return (MediaPerson(name: $0.name, role: .director, photoURL: photo, tmdbPersonId: $0.tmdbPersonId), $0)
    }
    let actors = TitleMetadata.enrich(
      names: mediaItem.castMembers,
      roleDepartment: "Acting",
      from: externalMetadata
    ).map {
      let photo = $0.photo
        ?? (allowPushbrFallback ? ActorImageProvider.photoURL(for: $0.name) : nil)
      return (MediaPerson(name: $0.name, role: .actor, photoURL: photo, tmdbPersonId: $0.tmdbPersonId), $0)
    }
    return directors + actors
  }

  var body: some View {
    if !people.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("Cast and crew", count: "\(people.count)")

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: Self.spacing) {
            ForEach(people, id: \.person.id) { entry in
              NavigationLink(value: linkProvider.person(for: entry.person)) {
                CastPortraitView(person: entry.person, member: entry.member)
              }
              .mediaZoomSource(id: "person-\(entry.person.id)")
              .buttonStyle(PortraitButtonStyle())
#if os(tvOS)
              .reportMediaItemSectionFocus(onSectionFocused)
#endif
            }
          }
          .padding(.horizontal, MediaItemLayout.horizontalInset)
          .padding(.vertical, Self.focusPadding)
        }
      }
    }
  }

#if os(tvOS)
  static let spacing: CGFloat = 28
  static let focusPadding: CGFloat = 16
#else
  static let spacing: CGFloat = 16
  static let focusPadding: CGFloat = 4
#endif
}

/// Poster-shaped portrait art shared by the cast rail and the person page hero.
///
/// Keeps the last successful decode across URL changes (pushbr → TMDB, size
/// upgrades) so `AsyncImage`'s `.empty` phase never flashes initials over a
/// face that was already on screen. Same sticky approach as the sidebar profile.
struct CastAvatarView: View {
  let name: String
  var photoURL: URL? = nil
  @Environment(\.colorScheme) private var colorScheme
  @State private var image: Image?
  @State private var loadedName: String?
  @State private var loadedURL: URL?

  var body: some View {
    ZStack {
      // Solid plate — focus shadow sits behind this, not through the gradient.
      Self.posterShape
        .fill(colorScheme == .dark ? Color.black : Color.white)

      if let image {
        image
          .resizable()
          .scaledToFill()
          .transition(.opacity)
      } else {
        placeholder
      }
    }
    .frame(width: Self.avatarWidth, height: Self.avatarHeight)
    .clipShape(Self.posterShape)
    .overlay { rimOverlay }
    .animation(.easeOut(duration: 0.2), value: image == nil)
    .task(id: loadKey) {
      await loadPhoto()
    }
  }

  private var loadKey: String {
    "\(name)|\(photoURL?.absoluteString ?? "")"
  }

  @MainActor
  private func loadPhoto() async {
    if loadedName != name {
      image = nil
      loadedURL = nil
      loadedName = name
    }

    guard let photoURL else { return }
    if loadedURL == photoURL, image != nil { return }

    do {
      let (data, response) = try await URLSession.shared.data(from: photoURL)
      guard !Task.isCancelled else { return }
      if let http = response as? HTTPURLResponse,
         !(200..<300).contains(http.statusCode) {
        return
      }
#if canImport(UIKit)
      guard let uiImage = UIImage(data: data) else { return }
      image = Image(uiImage: uiImage)
#elseif canImport(AppKit)
      guard let nsImage = NSImage(data: data) else { return }
      image = Image(nsImage: nsImage)
#endif
      loadedURL = photoURL
    } catch {
      // Keep any sticky image; initials stay if nothing loaded yet.
    }
  }

  private var placeholder: some View {
    ZStack {
      Self.posterShape
        .fill(
          LinearGradient(
            colors: [
              Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.14),
              Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
      Text(Self.initials(of: name))
        .font(Self.initialsFont)
        .foregroundStyle(Color.KinoPub.text)
    }
  }

  private var rimOverlay: some View {
    let rim = colorScheme == .dark ? Color.white : Color.black
    return Self.posterShape
      .strokeBorder(
        LinearGradient(
          colors: [rim.opacity(0.15), rim.opacity(0.4)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 0.5
      )
      .blur(radius: 0)
  }

  static func initials(of name: String) -> String {
    String(
      name.split(separator: " ")
        .prefix(2)
        .compactMap { $0.first }
        .map { String($0).uppercased() }
        .joined()
        .prefix(2)
    )
  }

  static let posterShape = RoundedRectangle(cornerRadius: 12, style: .continuous)
  static let avatarWidth: CGFloat = 100
  static let avatarHeight: CGFloat = 152

#if os(tvOS)
  static let initialsFont: Font = .system(size: 36, weight: .semibold, design: .rounded)
#else
  static let initialsFont: Font = .system(size: 36, weight: .semibold, design: .rounded)
#endif
}

/// Poster tile + name/role under it for the cast rail.
struct CastPortraitView: View {
  let person: MediaPerson
  let member: CastMember

  var body: some View {
    VStack(spacing: 8) {
      CastAvatarView(name: person.name, photoURL: person.photoURL)

      VStack(spacing: 4) {
        Text(person.name)
          .font(Self.nameFont)
          .foregroundStyle(Color.KinoPub.text)
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity, alignment: .center)

        subtitleLabel
          .font(Self.roleFont)
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity, alignment: .center)

        if let episodeCount = member.episodeCount, episodeCount > 0 {
          Text("\(episodeCount) \("MediaItem_EpisodesShort".localized)")
            .font(Self.roleFont)
            .foregroundStyle(Color.KinoPub.subtitle.opacity(0.7))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
        }
      }
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .frame(width: CastAvatarView.avatarWidth, alignment: .center)
  }

  /// Character when TMDB has one; otherwise the credit role (Actor / Director).
  @ViewBuilder
  private var subtitleLabel: some View {
    if let character = member.character?.trimmingCharacters(in: .whitespacesAndNewlines),
       !character.isEmpty {
      Text(character)
    } else {
      Text(person.role.titleKey.localized)
    }
  }

#if os(tvOS)
  static let nameFont: Font = .system(size: 24, weight: .medium)
  static let roleFont: Font = .system(size: 20, weight: .regular)
#else
  static let nameFont: Font = .system(size: 12, weight: .regular)
  static let roleFont: Font = .system(size: 12, weight: .regular)
#endif
}

/// The lift the episode cards use, kept a touch smaller: these sit in a denser
/// rail, where the same jump reads as a wobble. Pointer platforms also scale on press.
private struct PortraitButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Portrait(configuration: configuration)
  }

  private struct Portrait: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false

    var body: some View {
      configuration.label
        .scaleEffect(isFocused ? 1.05 : (configuration.isPressed ? 0.96 : 1.0))
        .shadow(color: .black.opacity(isFocused ? 0.45 : (isHovered ? 0.2 : 0)),
                radius: isFocused ? 14 : 8,
                y: isFocused ? 6 : 2)
        .animation(.easeOut(duration: 0.18), value: isFocused)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.spring(response: 0.15, dampingFraction: 0.9), value: configuration.isPressed)
#if !os(tvOS)
        .onHover { isHovered = $0 }
        .pointingHandCursorOnHover()
#endif
    }
  }
}

// MARK: - Similar

/// "More like this": the related items kino.pub returns for this one, drawn with the
/// same poster cards and horizontal rail as the home rows. Each card leads to that
/// item's own page, which is also what makes the rail reachable on tvOS — a scroll
/// view moves by focus, so plain artwork past the right edge would strand the user.
/// The whole section is absent until there is something to show.
struct MediaItemSimilarSection: View {

  let items: [MediaItem]
  let linkProvider: NavigationLinkProvider
  var onSectionFocused: (() -> Void)? = nil

  var body: some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("Similar")

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: Self.spacing) {
            ForEach(items, id: \.id) { item in
              NavigationLink(value: linkProvider.link(for: item)) {
                MediaCardView(card: MediaCard(item), caption: Self.cardCaption)
              }
#if os(tvOS)
              // Same native parallax focus effect as the catalog rows.
              .buttonStyle(.borderless)
              .reportMediaItemSectionFocus(onSectionFocused)
#else
              .buttonStyle(MediaCardButtonStyle())
#endif
            }
          }
          .padding(.horizontal, MediaItemLayout.horizontalInset)
          .padding(.vertical, Self.focusPadding)
        }
      }
    }
  }

#if os(tvOS)
  /// Match home: caption only while focused, so the rail stays a strip of posters.
  static let cardCaption: MediaCardCaption = .onFocus
  static let spacing: CGFloat = 36
  static let focusPadding: CGFloat = 32
#else
  static let cardCaption: MediaCardCaption = .always
  static let spacing: CGFloat = 16
  static let focusPadding: CGFloat = 6
#endif
}

// MARK: - Awards

/// From Kinopoisk Unofficial, when the user has their own key configured — hidden
/// entirely otherwise, same gate pattern as `MediaItemRatingsSection`.
struct MediaItemAwardsSection: View {
  let awards: [Award]
  var onSectionFocused: (() -> Void)? = nil

  var body: some View {
    if !awards.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("Awards")
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(awards.enumerated()), id: \.offset) { _, award in
            AwardRow(award: award, onSectionFocused: onSectionFocused)
          }
        }
        .padding(.horizontal, MediaItemLayout.horizontalInset)
      }
    }
  }
}

private struct AwardRow: View {
  let award: Award
  var onSectionFocused: (() -> Void)? = nil

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: award.won ? "trophy.fill" : "trophy")
        .foregroundStyle(award.won ? Color.yellow : Color.KinoPub.subtitle)
        .frame(width: 20)

      VStack(alignment: .leading, spacing: 2) {
        Text(award.nominationName.map { "\(award.name) — \($0)" } ?? award.name)
          .foregroundStyle(Color.KinoPub.text)
        if let year = award.year {
          Text(String(year))
            .font(.caption)
            .foregroundStyle(Color.KinoPub.subtitle)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.vertical, 6)
#if os(tvOS)
    .focusable(true)
    .reportMediaItemSectionFocus(onSectionFocused)
#endif
  }
}

// MARK: - Photos

struct MediaItemPhotosSection: View {
  let stills: [StillImage]
  var onSectionFocused: (() -> Void)? = nil
  @State private var selectedStill: StillImage?

  var body: some View {
    if !stills.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("Photos")
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: Self.spacing) {
            ForEach(stills) { still in
              Button {
                selectedStill = still
              } label: {
                stillTile(url: still.previewURL ?? still.url)
              }
#if os(tvOS)
              .buttonStyle(.borderless)
              .reportMediaItemSectionFocus(onSectionFocused)
#else
              .buttonStyle(.plain)
              .pointingHandCursorOnHover()
#endif
            }
          }
          .padding(.horizontal, MediaItemLayout.horizontalInset)
          .padding(.vertical, Self.focusPadding)
        }
      }
      .sheet(item: $selectedStill) { still in
        AsyncImage(url: still.url) { image in
          image.resizable().aspectRatio(contentMode: .fit)
        } placeholder: {
          ProgressView()
        }
      }
    }
  }

  private func stillTile(url: URL?) -> some View {
    AsyncImage(url: url) { image in
      image.resizable().aspectRatio(contentMode: .fill)
    } placeholder: {
      Color.KinoPub.selectionBackground
    }
    .frame(width: Self.tileWidth, height: Self.tileWidth * 9 / 16)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

#if os(tvOS)
  static let spacing: CGFloat = 24
  static let focusPadding: CGFloat = 24
  static let tileWidth: CGFloat = 320
#else
  static let spacing: CGFloat = 12
  static let focusPadding: CGFloat = 6
  static let tileWidth: CGFloat = 200
#endif
}

// MARK: - Community vote

/// Thumbs next to Ratings. kino.pub votes are one-shot — highlight sticks, no re-cast.
struct MediaItemCommunityVoteSection: View {
  let likeCount: Int
  let dislikeCount: Int
  let myVote: MediaItemUserVote
  var onVote: (Bool) -> Void
  var onSectionFocused: (() -> Void)? = nil

  var body: some View {
    HStack(spacing: MediaItemRatingsSection.spacing) {
      voteButton(up: true)
      voteButton(up: false)
    }
    .padding(.horizontal, MediaItemLayout.horizontalInset)
  }

  private func voteButton(up: Bool) -> some View {
    let active = myVote == (up ? .up : .down)
    let count = up ? likeCount : dislikeCount
    let symbol = active
      ? (up ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
      : (up ? "hand.thumbsup" : "hand.thumbsdown")
    return Button {
      onVote(up)
    } label: {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.system(size: Self.iconSize, weight: .semibold))
        if count > 0 {
          Text("\(count.formatted(.number.grouping(.automatic)))")
            .font(MediaItemRatingsSection.titleFont)
        }
      }
      .foregroundStyle(active ? (up ? Color.KinoPub.background : Color.white) : Color.KinoPub.text)
      .padding(.horizontal, MediaItemRatingsSection.tilePadding)
      .padding(.vertical, MediaItemRatingsSection.tilePadding * 0.7)
      .background(
        active
          ? (up ? Color.KinoPub.text : Color.red.opacity(0.85))
          : Color.KinoPub.selectionBackground.opacity(0.5),
        in: Capsule(style: .continuous)
      )
    }
    .buttonStyle(.borderless)
    .disabled(myVote != .none && !active)
    .accessibilityLabel(up ? "Like" : "Dislike")
#if os(tvOS)
    .reportMediaItemSectionFocus(onSectionFocused)
#endif
  }

#if os(tvOS)
  static let iconSize: CGFloat = 28
#else
  static let iconSize: CGFloat = 16
#endif
}

//private struct CommunityVoteButtonStyle: ButtonStyle {
//  func makeBody(configuration: Configuration) -> some View {
//    configuration.label
//      .opacity(configuration.isPressed ? 0.85 : 1)
//      .scaleEffect(configuration.isPressed ? 0.98 : 1)
//      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
//  }
//}

// MARK: - Facts

struct MediaItemFactsSection: View {
  let facts: [Fact]
  var onSectionFocused: (() -> Void)? = nil

  var body: some View {
    if !facts.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("Facts")
        VStack(alignment: .leading, spacing: 12) {
          ForEach(facts) { fact in
            FactRow(fact: fact, onSectionFocused: onSectionFocused)
          }
        }
        .padding(.horizontal, MediaItemLayout.horizontalInset)
      }
    }
  }
}

// MARK: - Reviews

struct MediaItemReviewsSection: View {
  let reviews: [Review]
  var onSectionFocused: (() -> Void)? = nil

  private var visible: [Review] { Array(reviews.prefix(Self.limit)) }

  var body: some View {
    if !visible.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("Reviews")
        VStack(alignment: .leading, spacing: 16) {
          ForEach(visible) { review in
            ReviewRow(review: review, onSectionFocused: onSectionFocused)
          }
        }
        .padding(.horizontal, MediaItemLayout.horizontalInset)
      }
    }
  }

  static let limit = 5
}

private struct ReviewRow: View {
  let review: Review
  var onSectionFocused: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 10) {
        if let sentiment = sentimentLabel {
          Text(sentiment)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.KinoPub.subtitle)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.KinoPub.selectionBackground.opacity(0.5),
                        in: Capsule(style: .continuous))
        }
        Text(review.author)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color.KinoPub.text)
          .lineLimit(1)
        if let date = review.date, !date.isEmpty {
          Text(date)
            .font(.caption)
            .foregroundStyle(Color.KinoPub.subtitle)
            .lineLimit(1)
        }
      }
      if !review.title.isEmpty {
        Text(review.title)
          .font(.headline)
          .foregroundStyle(Color.KinoPub.text)
          .fixedSize(horizontal: false, vertical: true)
      }
      Text(truncatedBody)
        .font(.body)
        .foregroundStyle(Color.KinoPub.subtitle)
        .fixedSize(horizontal: false, vertical: true)
    }
#if os(tvOS)
    .focusable(true)
    .reportMediaItemSectionFocus(onSectionFocused)
#endif
  }

  private var truncatedBody: String {
    let trimmed = review.body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > 420 else { return trimmed }
    let end = trimmed.index(trimmed.startIndex, offsetBy: 420)
    return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
  }

  private var sentimentLabel: String? {
    switch review.sentiment?.uppercased() {
    case "POSITIVE": return "Positive".localized
    case "NEGATIVE": return "Negative".localized
    case "NEUTRAL": return "Neutral".localized
    default: return nil
    }
  }
}

private struct FactRow: View {
  let fact: Fact
  var onSectionFocused: (() -> Void)? = nil
  @State private var isRevealed = false

  var body: some View {
    Group {
      if fact.isSpoiler && !isRevealed {
        Button {
          isRevealed = true
        } label: {
          Text("Tap to reveal spoiler")
            .italic()
            .foregroundStyle(Color.KinoPub.subtitle)
        }
        .buttonStyle(.plain)
      } else {
        Text(fact.text)
          .foregroundStyle(Color.KinoPub.text)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
#if os(tvOS)
    .focusable(true)
    .reportMediaItemSectionFocus(onSectionFocused)
#endif
  }
}

// MARK: - Information columns

/// Information · Languages · Technical, side by side where there is room and stacked
/// where there isn't — the shape Apple uses for Information · Languages · Accessibility.
///
/// Rows are stacked App Store–style (secondary caption, then semibold value), not
/// key-left / value-right. Languages merges audio and subtitles: voiceover first,
/// then subs, preferred (+ English) languages open, the rest behind "and N more".
///
/// Uploaded / Last Update and data-source links sit under the columns as a quiet
/// footer (credit-line style), outside the three columns.
///
/// Each column is a control rather than a block of text. tvOS scrolls by moving
/// focus, so a page whose bottom half holds nothing focusable cannot be scrolled to
/// at all — these columns were unreachable.
struct MediaItemInfoColumns: View {

  let mediaItem: MediaItem
  var externalMetadata: TitleMetadata = TitleMetadata()
  var onSectionFocused: (() -> Void)? = nil

  /// System preferred languages plus the app's second-subtitle choice — the set the
  /// Languages column keeps expanded by default.
  private var preferredLanguages: [String] {
    var languages = Locale.preferredLanguages
    let second = SubtitlePreferences.secondSubtitleLanguage
    if !languages.contains(where: { SubtitleTracks.matches(language: $0, second) }) {
      languages.append(second)
    }
    return languages
  }

  private var informationSections: [InfoSection] {
    var sections: [InfoSection] = []

    var typeValues: [InfoValue] = [
      InfoValue(id: "type",
                title: mediaItem.contentTypeTitleKey.localized,
                filter: mediaItem.contentTypeFilter.map { LibraryFilter(contentType: $0) })
    ]
    if let subtypeKey = mediaItem.contentSubtypeTitleKey {
      typeValues.append(InfoValue(id: "subtype", title: subtypeKey.localized))
    } else if let raw = mediaItem.contentSubtypeRaw {
      typeValues.append(InfoValue(id: "subtype", title: raw))
    }
    sections.append(InfoSection(id: "type", caption: "MediaItem_Type", values: typeValues))

    if let aka = mediaItem.alsoKnownAsTitle {
      sections.append(InfoSection(id: "aka",
                                  caption: "MediaItem_AlsoKnownAs",
                                  values: [InfoValue(id: "aka", title: aka)]))
    }

    let countries = mediaItem.countries
      .filter { !$0.title.isEmpty }
      .map {
        InfoValue(id: "country-\($0.id)",
                  title: $0.title,
                  filter: LibraryFilter(countryID: $0.id))
      }
    if !countries.isEmpty {
      let caption = countries.count == 1
        ? "MediaItem_CountryOfOrigin"
        : "MediaItem_CountriesOfOrigin"
      sections.append(InfoSection(id: "country", caption: caption, values: countries))
    }

    let genres = mediaItem.genres.compactMap { genre -> InfoValue? in
      guard let title = genre.title, !title.isEmpty else { return nil }
      return InfoValue(id: "genre-\(genre.id)",
                       title: title,
                       filter: LibraryFilter(genreID: genre.id))
    }
    if !genres.isEmpty {
      let caption = genres.count == 1 ? "MediaItem_Genre" : "MediaItem_Genres"
      sections.append(InfoSection(id: "genre", caption: caption, values: genres))
    }

    sections.append(contentsOf: releaseSections)

    let duration = mediaItem.displayDuration
    if !duration.isEmpty {
      let caption = mediaItem.isSeries
        ? "MediaItem_EpisodeRuntime"
        : "MediaItem_Runtime"
      sections.append(InfoSection(id: "duration",
                                  caption: caption,
                                  values: [InfoValue(id: "duration", title: duration)]))
    }

    if let total = mediaItem.totalDurationDisplay {
      var totalValues = [InfoValue(id: "total", title: total)]
      if let note = mediaItem.continuousWatchNoteParts {
        let text = String(format: "MediaItem_ContinuousWatchHint".localized,
                          note.compact,
                          note.totalMinutes)
        totalValues.append(InfoValue(id: "total-note", title: text, style: .note))
      }
      sections.append(InfoSection(id: "total",
                                  caption: "MediaItem_TotalDuration",
                                  values: totalValues))
    }

    var flagValues: [InfoValue] = []
    if mediaItem.advert {
      flagValues.append(InfoValue(id: "advert", title: "MediaItem_ContainsAds".localized))
    }
    if mediaItem.poorQuality {
      flagValues.append(InfoValue(id: "poor", title: "MediaItem_PoorQuality".localized))
    }
    if !flagValues.isEmpty {
      sections.append(InfoSection(id: "flags",
                                  caption: "MediaItem_Flags",
                                  values: flagValues))
    }

    return sections
  }

  /// Release / expected release / season premiere / status / totals — the date-driven
  /// block fed by TMDB air dates, with kino.pub's year as the final fallback.
  private var releaseSections: [InfoSection] {
    var sections: [InfoSection] = []
    let meta = externalMetadata

    if !mediaItem.isSeries {
      if let date = meta.releaseDate {
        sections.append(InfoSection(id: "release", caption: "MediaItem_Release",
                                    values: [InfoValue(id: "release", title: Self.longDate(date))]))
      } else if mediaItem.year > 0 {
        sections.append(InfoSection(id: "release", caption: "MediaItem_Release",
                                    values: [InfoValue(id: "release", title: "\(mediaItem.year)")]))
      }
      return sections
    }

    let kinoEpisodes = mediaItem.volumeCounts?.episodes ?? 0
    if let announced = announcedReleaseDate, kinoEpisodes == 0 {
      sections.append(InfoSection(id: "expected", caption: "MediaItem_ExpectedRelease",
                                  values: [InfoValue(id: "expected", title: Self.longDate(announced))]))
    } else if let release = seriesReleaseText {
      sections.append(InfoSection(id: "release", caption: "MediaItem_Release",
                                  values: [InfoValue(id: "release", title: release)]))
    }

    if let upcoming = upcomingEpisodeSection {
      sections.append(upcoming)
    }

    if let statusKey = seriesStatusKey {
      sections.append(InfoSection(id: "status", caption: "MediaItem_Status",
                                  values: [InfoValue(id: "status", title: statusKey.localized)]))
    }

    if let totals = totalExistsText {
      sections.append(InfoSection(id: "total-exists", caption: "MediaItem_TotalExists",
                                  values: [InfoValue(id: "total-exists", title: totals)]))
    }

    if let available = availableText {
      sections.append(InfoSection(id: "available", caption: "MediaItem_Available",
                                  values: [InfoValue(id: "available", title: available)]))
    }

    return sections
  }

  /// A series announced but with nothing aired yet — the first known future date.
  private var announcedReleaseDate: Date? {
    if let first = externalMetadata.firstAirDate, first > Date() { return first }
    if let next = externalMetadata.nextEpisode?.airDate, next > Date() { return next }
    return nil
  }

  private var isFinished: Bool {
    switch externalMetadata.status?.lowercased() {
    case "ended", "canceled": return true
    case "returning series", "in production", "pilot", "planned": return false
    default: return mediaItem.finished
    }
  }

  private var seriesStatusKey: String? {
    guard mediaItem.isSeries else { return nil }
    switch externalMetadata.status?.lowercased() {
    case "ended": return "MediaItem_StatusEnded"
    case "canceled": return "MediaItem_StatusCanceled"
    case "returning series", "in production", "pilot", "planned":
      return "MediaItem_StatusInProduction"
    default: return mediaItem.seriesStatusKey
    }
  }

  /// "21 сентября 2020 – 30 июля 2026" when the run is complete, "с 21 сентября 2020"
  /// while it is still airing, bare years when only they are known.
  private var seriesReleaseText: String? {
    switch (externalMetadata.firstAirDate, externalMetadata.lastAirDate) {
    case let (first?, last?):
      if isFinished { return "\(Self.longDate(first)) – \(Self.longDate(last))" }
      return String(format: "MediaItem_SinceDate".localized, Self.longDate(first))
    case let (first?, nil):
      if isFinished { return Self.longDate(first) }
      return String(format: "MediaItem_SinceDate".localized, Self.longDate(first))
    default:
      guard mediaItem.year > 0 else { return nil }
      return isFinished ? "\(mediaItem.year)" : "\(mediaItem.year)–"
    }
  }

  /// "Премьера 19 сезона" when the next episode opens a new season, "Следующая серия"
  /// when it continues the current one — date primary, countdown secondary.
  private var upcomingEpisodeSection: InfoSection? {
    guard mediaItem.isSeries,
          let next = externalMetadata.nextEpisode,
          let date = next.airDate, date > Date() else { return nil }

    let lastAiredSeason = externalMetadata.lastEpisode?.seasonNumber
      ?? externalMetadata.seasonSummaries
        .filter { ($0.airDate ?? .distantFuture) <= Date() }
        .map(\.seasonNumber)
        .max()
    let isSeasonPremiere = lastAiredSeason.map { next.seasonNumber > $0 } ?? false
    let caption = isSeasonPremiere
      ? String(format: "MediaItem_SeasonPremiere".localized, next.seasonNumber)
      : "MediaItem_NextEpisode".localized

    var values = [InfoValue(id: "next", title: Self.longDate(date))]
    let countdown = Self.relativeCountdown(to: date)
    if !countdown.isEmpty {
      values.append(InfoValue(id: "next-in", title: countdown, style: .note))
    }
    return InfoSection(id: isSeasonPremiere ? "season-premiere" : "next-episode",
                       caption: caption,
                       values: values)
  }

  /// "18 сезонов, 386 серий" — TMDB totals (specials excluded), with a specials note
  /// when season 0 exists and kino.pub doesn't carry everything.
  private var totalExistsText: String? {
    guard mediaItem.isSeries,
          let seasonsTotal = externalMetadata.numberOfSeasons, seasonsTotal > 0 else { return nil }
    var text = "\(seasonsTotal) \(Self.unit(seasonsTotal, .season))"
    guard let episodesTotal = externalMetadata.numberOfEpisodes, episodesTotal > 0 else { return text }
    text += ", \(episodesTotal) \(Self.unit(episodesTotal, .episode))"

    let specials = externalMetadata.seasonSummaries
      .filter { $0.seasonNumber == 0 }
      .reduce(0) { $0 + ($1.episodeCount ?? 0) }
    let kinoEpisodes = mediaItem.volumeCounts?.episodes ?? 0
    if specials > 0, kinoEpisodes < episodesTotal {
      text += ", \(specials) \(Self.unit(specials, .special))"
    }
    return text
  }

  /// "Сезоны 14–18, 100 серий" — what kino.pub actually offers, real season numbers
  /// (title-parsed) rather than its internal re-numbering.
  private var availableText: String? {
    guard mediaItem.isSeries,
          let seasons = mediaItem.seasons, !seasons.isEmpty else { return nil }
    let numbers = seasons.map { $0.titleSeasonNumber ?? $0.number }.sorted()
    let episodes = seasons.reduce(0) { $0 + $1.episodes.count }
    let episodesText = episodes > 0 ? ", \(episodes) \(Self.unit(episodes, .episode))" : ""

    guard let first = numbers.first, let last = numbers.last, first != last else {
      return String(format: "MediaItem_SeasonSingle".localized, numbers.first ?? 1) + episodesText
    }
    if last - first + 1 == numbers.count {
      return String(format: "MediaItem_SeasonsRange".localized, first, last) + episodesText
    }
    return "\(numbers.count) \(Self.unit(numbers.count, .season))" + episodesText
  }

  private static let longDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
    return formatter
  }()

  private static func longDate(_ date: Date) -> String {
    longDateFormatter.string(from: date)
  }

  /// "через 12 дней" / "in 12 days" — localized by the system, plural rules included.
  private static func relativeCountdown(to date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  private enum UnitKind { case season, episode, special }

  /// Grammatically correct unit for the running locale: RU/UK/BE and LT have three
  /// plural forms, English two.
  private static func unit(_ count: Int, _ kind: UnitKind) -> String {
    let lang = Locale.current.language.languageCode?.identifier ?? "en"
    let mod100 = count % 100
    let mod10 = count % 10
    let form: Int  // 0 = one, 1 = few, 2 = many
    if ["ru", "uk", "be"].contains(lang) {
      if (11...14).contains(mod100) { form = 2 }
      else if mod10 == 1 { form = 0 }
      else if (2...4).contains(mod10) { form = 1 }
      else { form = 2 }
    } else if lang == "lt" {
      if mod10 == 1 && mod100 != 11 { form = 0 }
      else if (2...9).contains(mod10) && !(10...19).contains(mod100) { form = 1 }
      else { form = 2 }
    } else {
      form = count == 1 ? 0 : 2
    }

    let key: String
    switch (kind, form) {
    case (.season, 0): key = "MediaItem_UnitSeasonOne"
    case (.season, 1): key = "MediaItem_UnitSeasonFew"
    case (.season, 2): key = "MediaItem_UnitSeasonMany"
    case (.episode, 0): key = "MediaItem_UnitEpisodeOne"
    case (.episode, 1): key = "MediaItem_UnitEpisodeFew"
    case (.episode, 2): key = "MediaItem_UnitEpisodeMany"
    case (.special, 0): key = "MediaItem_UnitSpecialOne"
    case (.special, 1): key = "MediaItem_UnitSpecialFew"
    case (.special, 2): key = "MediaItem_UnitSpecialMany"
    default: key = "MediaItem_UnitSeasonMany"
    }
    return key.localized
  }

  private var technicalSections: [InfoSection] {
    var sections: [InfoSection] = []

    if let rating = externalMetadata.ageRating, !rating.isEmpty {
      sections.append(InfoSection(id: "age",
                                  caption: "MediaItem_AgeRating",
                                  values: [InfoValue(id: "age", title: rating)]))
    }

    var qualityValues: [InfoValue] = []
    let tech = mediaItem.videoTechLines
    if !tech.isEmpty {
      qualityValues = tech.enumerated().map {
        InfoValue(id: "track-\($0.offset)", title: $0.element)
      }
    } else if let quality = mediaItem.qualityDisplay {
      qualityValues = [InfoValue(id: "quality", title: quality)]
    }
    if !qualityValues.isEmpty {
      sections.append(InfoSection(id: "quality",
                                  caption: "MediaItem_VideoQuality",
                                  values: qualityValues))
    }

    if let ac3 = mediaItem.ac3, ac3 > 0 {
      sections.append(InfoSection(id: "ac3",
                                  caption: "MediaItem_AudioCodec",
                                  values: [InfoValue(id: "ac3", title: "AC3")]))
    }

    return sections
  }

  private var audioGroups: [MediaLanguageGroup] {
    mediaItem.audioLanguageGroups(preferredLanguages: preferredLanguages)
  }

  private var subtitleGroups: [MediaLanguageGroup] {
    mediaItem.subtitleLanguageGroups(preferredLanguages: preferredLanguages)
  }

  private var showsLanguagesColumn: Bool {
    !audioGroups.isEmpty || !subtitleGroups.isEmpty
  }

  private var showsTechnicalColumn: Bool {
    !technicalSections.isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Self.footerSpacing) {
      ViewThatFits(in: .horizontal) { // НЕТ КАК РАЗ ТУТ НАДО НАОБОРОТ ОНО ДОЛЖНО ЗАЛИВАТЬ ВСЮ ШИРИНУ И эти колонки должны заполнять нопополам....... а не влево стекаться
        HStack(alignment: .top, spacing: Self.columnSpacing) {
          columnViews
        }
        VStack(alignment: .leading, spacing: Self.columnSpacing) {
          columnViews
        }
      }

      InfoFooter(mediaItem: mediaItem,
                 attribution: externalMetadata.attribution,
                 tmdbId: externalMetadata.tmdbId,
                 isSeries: mediaItem.isSeries,
                 debugLog: externalMetadata.debugLog,
                 onSectionFocused: onSectionFocused)

      MetadataReferenceSection(onSectionFocused: onSectionFocused)
    }
    .padding(.horizontal, MediaItemLayout.horizontalInset)
  }

  @ViewBuilder
  private var columnViews: some View {
    InformationColumn(title: "Information",
                      sections: informationSections,
                      onSectionFocused: onSectionFocused)
    if showsLanguagesColumn {
      LanguagesColumn(audioGroups: audioGroups,
                      subtitleGroups: subtitleGroups,
                      preferredLanguages: preferredLanguages,
                      onSectionFocused: onSectionFocused)
    }
    if showsTechnicalColumn {
      InformationColumn(title: "MediaItem_Technical",
                        sections: technicalSections,
                        onSectionFocused: onSectionFocused)
    }
  }

  private enum ValueStyle {
    case primary
    case note
  }

  private struct InfoValue: Identifiable {
    let id: String
    let title: String
    /// When set, the value opens Search with this filter.
    var filter: LibraryFilter? = nil
    var style: ValueStyle = .primary
  }

  private struct InfoSection: Identifiable {
    let id: String
    let caption: String
    let values: [InfoValue]
  }

  // MARK: Information / Technical

  private struct InformationColumn: View {
    let title: LocalizedStringKey
    let sections: [InfoSection]
    var onSectionFocused: (() -> Void)? = nil
    @EnvironmentObject var navigationState: NavigationState
    @State private var hoveredValueID: String?

    var body: some View {
      VStack(alignment: .leading, spacing: MediaItemInfoColumns.sectionSpacing) {
        Text(title)
          .font(MediaItemInfoColumns.headerFont)
          .foregroundStyle(Color.KinoPub.text)

        ForEach(sections) { section in
          sectionBlock(section)
        }
      }
      // Equal share of the row — the columns fill the page width instead of
      // stacking to the left at a fixed width.
      .frame(maxWidth: .infinity, alignment: .leading)
#if os(tvOS)
      .reportMediaItemSectionFocus(onSectionFocused)
#endif
    }

    @ViewBuilder
    private func sectionBlock(_ section: InfoSection) -> some View {
      VStack(alignment: .leading, spacing: MediaItemInfoColumns.stackSpacing) {
        Text(LocalizedStringKey(section.caption))
          .font(MediaItemInfoColumns.captionFont)
          .foregroundStyle(Color.KinoPub.subtitle)

        ForEach(section.values) { value in
          if let filter = value.filter {
            Button {
              navigationState.openSearch(filter: filter, title: value.title)
            } label: {
              Text(value.title)
                .font(MediaItemInfoColumns.valueFont)
                .foregroundStyle(Color.KinoPub.text)
                .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(InfoLinkButtonStyle(showsChevron: hoveredValueID == value.id))
#if os(macOS)
            .onHover { hovering in
              hoveredValueID = hovering ? value.id : nil
              if hovering {
                NSCursor.pointingHand.push()
              } else {
                NSCursor.pop()
              }
            }
#elseif os(iOS)
            .onHover { hovering in
              hoveredValueID = hovering ? value.id : nil
            }
#endif
#if os(tvOS)
            .reportMediaItemSectionFocus(onSectionFocused)
#endif
          } else {
            Text(value.title)
              .font(value.style == .note
                    ? MediaItemInfoColumns.captionFont
                    : MediaItemInfoColumns.plainValueFont)
              .foregroundStyle(value.style == .note
                               ? Color.KinoPub.subtitle
                               : Color.KinoPub.text)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }

  /// Hover / focus: opacity 0.8 and a trailing chevron on the value itself.
  private struct InfoLinkButtonStyle: ButtonStyle {
    var showsChevron: Bool

    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
      InfoLinkLabel(configuration: configuration, showsChevron: showsChevron)
    }
  }

  private struct InfoLinkLabel: View {
    let configuration: ButtonStyle.Configuration
    let showsChevron: Bool
    @Environment(\.isFocused) private var isFocused

    private var active: Bool { showsChevron || isFocused }

    var body: some View {
      HStack(spacing: 6) {
        configuration.label
          .opacity(active ? 0.8 : 1)
        if active {
          Image(systemName: "chevron.right")
            .font(MediaItemInfoColumns.captionFont)
            .foregroundStyle(Color.KinoPub.subtitle.opacity(0.85))
            .transition(.opacity)
        }
      }
      .animation(.easeOut(duration: 0.18), value: active)
    }
  }

  // MARK: Languages

  private struct LanguagesColumn: View {
    let audioGroups: [MediaLanguageGroup]
    let subtitleGroups: [MediaLanguageGroup]
    let preferredLanguages: [String]
    var onSectionFocused: (() -> Void)? = nil

    @State private var showsAllAudio = false
    @State private var showsAllSubtitles = false

    private var collapsedAudio: (visible: [MediaLanguageGroup], hiddenCount: Int) {
      LanguageListVisibility.partition(audioGroups, preferredLanguages: preferredLanguages)
    }

    private var collapsedSubtitles: (visible: [MediaLanguageGroup], hiddenCount: Int) {
      LanguageListVisibility.partition(subtitleGroups, preferredLanguages: preferredLanguages)
    }

    private var audioPartition: (visible: [MediaLanguageGroup], hiddenCount: Int) {
      showsAllAudio ? (audioGroups, 0) : collapsedAudio
    }

    private var subtitlePartition: (visible: [MediaLanguageGroup], hiddenCount: Int) {
      showsAllSubtitles ? (subtitleGroups, 0) : collapsedSubtitles
    }

    private var canExpand: Bool {
      (!showsAllAudio && collapsedAudio.hiddenCount >= 2)
        || (!showsAllSubtitles && collapsedSubtitles.hiddenCount >= 2)
    }

    var body: some View {
      Button {
        guard canExpand else { return }
        showsAllAudio = true
        showsAllSubtitles = true
      } label: {
        VStack(alignment: .leading, spacing: MediaItemInfoColumns.sectionSpacing) {
          Text("Languages")
            .font(MediaItemInfoColumns.headerFont)
            .foregroundStyle(Color.KinoPub.text)

          if !audioGroups.isEmpty {
            audioSection(groups: audioPartition.visible,
                         moreCount: audioPartition.hiddenCount)
          }
          if !subtitleGroups.isEmpty {
            subtitleSection(groups: subtitlePartition.visible,
                            moreCount: subtitlePartition.hiddenCount)
              .padding(.top, MediaItemInfoColumns.subtitleExtraTop)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(ExpandableButtonStyle(showsPointerHighlight: false))
#if os(tvOS)
      .reportMediaItemSectionFocus(onSectionFocused)
#endif
    }

    @ViewBuilder
    private func audioSection(groups: [MediaLanguageGroup], moreCount: Int) -> some View {
      VStack(alignment: .leading, spacing: MediaItemInfoColumns.languageNameToKindSpacing) {
        Text("MediaItem_Voice")
          .font(MediaItemInfoColumns.captionFont)
          .foregroundStyle(Color.KinoPub.subtitle)

        VStack(alignment: .leading, spacing: MediaItemInfoColumns.languageGroupSpacing) {
          ForEach(groups) { group in
            VStack(alignment: .leading, spacing: MediaItemInfoColumns.languageNameToKindSpacing) {
              Text(group.name)
                .font(MediaItemInfoColumns.valueFont)
                .foregroundStyle(Color.KinoPub.text)
              ForEach(Array(group.detailLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                  .font(MediaItemInfoColumns.detailFont)
                  .foregroundStyle(Color.KinoPub.text)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          }
        }

        if moreCount >= 2 {
          moreLabel(moreCount)
        }
      }
    }

    @ViewBuilder
    private func subtitleSection(groups: [MediaLanguageGroup], moreCount: Int) -> some View {
      VStack(alignment: .leading, spacing: MediaItemInfoColumns.languageNameToKindSpacing) {
        Text("Subtitles")
          .font(MediaItemInfoColumns.captionFont)
          .foregroundStyle(Color.KinoPub.subtitle)

        Text(groups.map(\.name).joined(separator: ", "))
          .font(MediaItemInfoColumns.plainValueFont)
          .foregroundStyle(Color.KinoPub.text)
          .fixedSize(horizontal: false, vertical: true)

        if moreCount >= 2 {
          moreLabel(moreCount)
        }
      }
    }

    private func moreLabel(_ count: Int) -> some View {
      HStack(spacing: 6) {
        Text("and \(count) more")
        Image(systemName: "chevron.down")
      }
      .font(MediaItemInfoColumns.captionFont)
      .foregroundStyle(Color.KinoPub.subtitle.opacity(0.85))
    }
  }

  private static func date(_ timestamp: Int) -> String {
    guard timestamp > 0 else { return "—" }
    return Date(timeIntervalSince1970: TimeInterval(timestamp))
      .formatted(date: .abbreviated, time: .omitted)
  }

  // MARK: Footer

  /// Uploaded / Last Update plus quiet source buttons on non-TV — same secondary
  /// weight throughout, not another Information row.
  private struct InfoFooter: View {
    let mediaItem: MediaItem
    let attribution: Set<MetadataSourceID>
    let tmdbId: Int?
    let isSeries: Bool
    var debugLog: [SourceDebugEntry] = []
    var onSectionFocused: (() -> Void)? = nil
    @Environment(\.openURL) private var openURL
    @State private var showsDebugSheet = false

    var body: some View {
      HStack(alignment: .center, spacing: 10) {
        creditText(label: "MediaItem_Uploaded",
                   value: MediaItemInfoColumns.date(mediaItem.createdAt))
        if !mediaItem.uploadedSameDayAsUpdated {
            creditText(label: "∙", value: "")

          creditText(label: "MediaItem_LastUpdate",
                     value: MediaItemInfoColumns.date(mediaItem.updatedAt))
        }
#if !os(tvOS)
// creditText(label: "MediaItem_Source", value: "Kino.watch")
        sourceButton(title: "kino.watch", url: kinopubURL)
        if attribution.contains(.tmdb) {
          sourceButton(title: "TMDB", url: tmdbURL)
        }
#endif
        // Dev tool, all platforms — unlike the links above, there's nothing to
        // browse to on tvOS, so it isn't gated the same way.
        debugButton
      }
      .font(MediaItemInfoColumns.captionFont)
      .foregroundStyle(Color.KinoPub.subtitle)
      .sheet(isPresented: $showsDebugSheet) {
        DebugLogView(entries: debugLog)
      }
    }

    private var debugButton: some View {
      Button {
        showsDebugSheet = true
      } label: {
        HStack(alignment: .center, spacing: 4) {
          Text(verbatim: "Debug")
          Image(systemName: "ladybug")
        }
      }
      .buttonStyle(SourceChipButtonStyle())
#if os(tvOS)
      .reportMediaItemSectionFocus(onSectionFocused)
#endif
    }

    private var kinopubURL: URL {
      URL(string: "https://kino.watch/item/view/\(mediaItem.id)")!
    }

    private var tmdbURL: URL {
      if let tmdbId {
        let kind = isSeries ? "tv" : "movie"
        return URL(string: "https://www.themoviedb.org/\(kind)/\(tmdbId)")!
      }
      return URL(string: "https://www.themoviedb.org")!
    }

    private func creditText(label: String, value: String) -> Text {
      Text("\(label.localized) \(value)")
    }

    private func sourceButton(title: String, url: URL) -> some View {
      Button {
        openURL(url)
      } label: {
        HStack(alignment: .center, spacing: 4) {
          Text(title)
          Image(systemName: "arrow.up.right")
        }
      }
      .buttonStyle(SourceChipButtonStyle())
    }
  }

  /// Raw request/response dump per source, for verifying what actually came back
  /// (and whether via our proxy) without a separate debugging setup. Dev tool —
  /// not for end users, hence the unlocalized "Debug"/verbatim labels throughout.
  private struct DebugLogView: View {
    let entries: [SourceDebugEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
      NavigationStack {
        Group {
          if entries.isEmpty {
            ContentUnavailableView(
              "No requests recorded",
              systemImage: "questionmark.folder",
              description: Text(verbatim: "Either no metadata source is configured for this title, or every field on it came from kino.pub alone.")
            )
          } else {
            ScrollView {
              VStack(alignment: .leading, spacing: 20) {
                ForEach(entries) { entry in
                  DebugEntryRow(entry: entry)
                }
              }
              .padding()
            }
          }
        }
        .platformNavigationTitle("Metadata debug (\(entries.count))")
#if !os(tvOS)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              dismiss()
            } label: {
              Text("Close")
            }
          }
        }
#endif
      }
    }
  }

  private struct DebugEntryRow: View {
    let entry: SourceDebugEntry

    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Text(verbatim: "\(entry.source.rawValue) · \(entry.endpoint)")
            .font(.system(size: 15, weight: .semibold))
          Spacer()
          badge(entry.proxied ? "proxied" : "direct", tint: .secondary)
          badge(entry.succeeded ? "ok" : "failed", tint: entry.succeeded ? .green : .red)
        }
        Text(entry.url)
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.secondary)
#if !os(tvOS)
          .textSelection(.enabled)
#endif
        Text(Self.prettyPrinted(entry.responseBody))
          .font(.system(size: 11, design: .monospaced))
#if !os(tvOS)
          .textSelection(.enabled)
#endif
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.KinoPub.selectionBackground.opacity(0.5),
                      in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
    }

    private func badge(_ text: String, tint: Color) -> some View {
      Text(verbatim: text)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(0.15), in: Capsule())
    }

    /// Best-effort reformat for readability — falls back to the raw text as-is
    /// (e.g. for the non-JSON "no response"/"not found" placeholder bodies).
    private static func prettyPrinted(_ raw: String) -> String {
      guard let data = raw.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: pretty, encoding: .utf8)
      else { return raw }
      return text
    }
  }

  /// Dev-facing map of every TMDB/Kinopoisk field or endpoint touched by this session's
  /// integration work — what's actually parsed today vs. fetched-but-discarded vs. never
  /// called. Hand-curated against real API responses, not the docs; re-audit before trusting
  /// it against a newer TMDB/Kinopoisk response shape. Not for end-user consumption.
  private struct MetadataReferenceSection: View {
    var onSectionFocused: (() -> Void)? = nil

    private enum RowStatus: String {
      case parsed = "Parsed"
      case fetchedUnused = "Fetched, unused"
      case available = "Available"

      var tint: Color {
        switch self {
        case .parsed: .green
        case .fetchedUnused: .orange
        case .available: .secondary
        }
      }
    }

    private struct Row: Identifiable {
      let id: Int
      let source: String
      let name: String
      let status: RowStatus
    }

    private static let rows: [Row] = {
      var rows: [Row] = []
      var next = 0
      func add(_ source: String, _ name: String, _ status: RowStatus) {
        rows.append(Row(id: next, source: source, name: name, status: status))
        next += 1
      }

      add("TMDB", "/find (resolve by IMDb id)", .parsed)
      add("TMDB", "/movie|tv/{id} (base details)", .parsed)
      add("TMDB", "append_to_response: credits, aggregate_credits", .parsed)
      add("TMDB", "append_to_response: images", .parsed)
      add("TMDB", "append_to_response: videos", .parsed)
      add("TMDB", "append_to_response: release_dates, content_ratings", .parsed)
      add("TMDB", "append_to_response: keywords", .parsed)
      add("TMDB", "append_to_response: external_ids → imdb_id", .parsed)
      add("TMDB", "tagline", .parsed)
      add("TMDB", "homepage", .parsed)
      add("TMDB", "budget, revenue", .parsed)
      add("TMDB", "production_companies, networks", .parsed)
      add("TMDB", "next_episode_to_air, last_episode_to_air", .parsed)
      add("TMDB", "/tv/{id}/season/{n} (episode schedule)", .parsed)
      add("TMDB", "/person/{id} (bio, birthday, photo)", .parsed)
      add("TMDB", "overview", .fetchedUnused)
      add("TMDB", "genres", .fetchedUnused)
      add("TMDB", "external_ids → tvdb_id, facebook_id, instagram_id, twitter_id", .fetchedUnused)
      add("TMDB", "vote_average, vote_count", .fetchedUnused)
      add("TMDB", "/movie|tv/{id}/reviews", .available)
      add("TMDB", "/movie|tv/{id}/recommendations", .available)
      add("TMDB", "/movie|tv/{id}/similar", .available)
      add("TMDB", "/movie|tv/{id}/alternative_titles", .available)
      add("TMDB", "/movie|tv/{id}/translations", .available)
      add("TMDB", "/movie|tv/{id}/watch/providers", .available)
      add("TMDB", "/collection/{id} (belongs_to_collection)", .available)
      add("TMDB", "/discover/movie|tv", .available)
      add("TMDB", "/trending/...", .available)
      add("TMDB", "/certification/movie|tv/list", .available)

      add("Kinopoisk", "/api/v2.2/films/{id} (details → artwork)", .parsed)
      add("Kinopoisk", "/api/v1/staff?filmId= (cast/crew, RU names)", .parsed)
      add("Kinopoisk", "/api/v2.2/films/{id}/awards", .parsed)
      add("Kinopoisk", "/api/v2.2/films/{id}/images?type=STILL", .parsed)
      add("Kinopoisk", "/api/v2.2/films/{id}/facts", .parsed)
      add("Kinopoisk", "/api/v1/staff/{staffId} (person bio)", .available)
      add("Kinopoisk", "/api/v2.2/films/{id}/box_office", .available)
      add("Kinopoisk", "/api/v2.2/films/{id}/videos", .available)
      add("Kinopoisk", "/api/v2.2/films/{id}/reviews", .available)
      add("Kinopoisk", "/api/v2.2/films/{id}/similars", .available)
      add("Kinopoisk", "/api/v2.2/films/{id}/relations", .available)
      add("Kinopoisk", "/api/v2.1/films/{id}/sequels_and_prequels", .available)
      add("Kinopoisk", "/api/v2.2/films/collections?type=...", .available)

      return rows
    }()

    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(verbatim: "Metadata field/endpoint reference")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Color.KinoPub.text)
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5) {
          GridRow {
            Text(verbatim: "Source").foregroundStyle(.secondary)
            Text(verbatim: "Field / endpoint").foregroundStyle(.secondary)
            Text(verbatim: "Status").foregroundStyle(.secondary)
          }
          .font(.system(size: 11, weight: .semibold))
          ForEach(Self.rows) { row in
            GridRow {
              Text(verbatim: row.source)
              Text(verbatim: row.name)
              Text(verbatim: row.status.rawValue)
                .foregroundStyle(row.status.tint)
            }
            .font(.system(size: 12, design: .monospaced))
          }
        }
      }
#if os(tvOS)
      .focusable(true)
      .reportMediaItemSectionFocus(onSectionFocused)
#endif
    }
  }

#if os(tvOS)
  static let columnSpacing: CGFloat = 60
  static let sectionSpacing: CGFloat = 22
  static let languageGroupSpacing: CGFloat = 12
  static let languageNameToKindSpacing: CGFloat = 3
  static let subtitleExtraTop: CGFloat = 8
  static let stackSpacing: CGFloat = 4
  static let footerSpacing: CGFloat = 28
  static let headerFont: Font = .system(size: 30, weight: .semibold)
  static let captionFont: Font = .system(size: 22, weight: .regular)
  static let valueFont: Font = .system(size: 22, weight: .semibold)
  static let plainValueFont: Font = .system(size: 22, weight: .regular)
  static let detailFont: Font = .system(size: 22, weight: .regular)
#else
  static let columnSpacing: CGFloat = 28
  static let sectionSpacing: CGFloat = 16
  static let languageGroupSpacing: CGFloat = 8
  static let languageNameToKindSpacing: CGFloat = 1
  static let subtitleExtraTop: CGFloat = 8
  static let stackSpacing: CGFloat = 2
  static let footerSpacing: CGFloat = 20
  static let headerFont: Font = .system(size: 18, weight: .bold)
  static let captionFont: Font = .system(size: 13, weight: .regular)
  static let valueFont: Font = .system(size: 13, weight: .medium)
  static let plainValueFont: Font = .system(size: 13, weight: .regular)
  static let detailFont: Font = .system(size: 13, weight: .regular)
#endif
}

/// Rating-tile cousin for footer source chips — light plate, hover brighten, press scale.
private struct SourceChipButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyle.Configuration) -> some View {
    Chip(configuration: configuration)
  }

  private struct Chip: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovered = false

    var body: some View {
      configuration.label
        .font(MediaItemInfoColumns.captionFont)
        .foregroundStyle(Color.KinoPub.subtitle) // бля даже кнопку верстать приходитса бро???
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
          Color.KinoPub.selectionBackground.opacity(isHovered ? 0.5 : 0),
          in: Capsule()
        )
        .scaleEffect(configuration.isPressed ? 0.96 : 1)
//        .shadow(color: .black.opacity(isHovered ? 0.18 : 0), radius: 6, y: 2)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .animation(.spring(response: 0.15, dampingFraction: 0.9), value: configuration.isPressed)
#if !os(tvOS)
        .onHover { isHovered = $0 }
        .pointingHandCursorOnHover()
#endif
    }
  }
}

// MARK: - Shared bits

struct MediaItemSectionHeader: View {
  private let title: LocalizedStringKey
  private let count: String?

  init(_ title: LocalizedStringKey, count: String? = nil) {
    self.title = title
    self.count = count
  }

  var body: some View {
    SectionHeader(title, count: count, leadingInset: MediaItemLayout.horizontalInset)
  }
}

enum MediaItemLayout {
  /// The page's scroll view names its own frame so non-tvOS heroes can tell where
  /// they sit relative to what is on screen — see `MediaItemHeroView.visibilityProbe`.
  static let scrollSpace = "MediaItemScroll"

#if os(tvOS)
  static let horizontalInset: CGFloat = 80
  static let sectionSpacing: CGFloat = 44
  static let headerFont: Font = .system(size: 32, weight: .semibold)
#elseif os(macOS)
  static let horizontalInset: CGFloat = 32
  static let sectionSpacing: CGFloat = 28
  static let headerFont: Font = .system(size: 22, weight: .semibold)
#else
  static let horizontalInset: CGFloat = 20
  static let sectionSpacing: CGFloat = 24
  static let headerFont: Font = .system(size: 20, weight: .semibold)
#endif
}

// MARK: - Plot

/// The clamped synopsis' drawn height, and the same text measured with no line limit.
/// Two keys rather than one so the plot view can compare them without either
/// measurement having to know the other's value.
private struct PlotClampedHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct PlotFullHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// The synopsis, clamped to a few lines and focusable as a single control. Selecting
/// it opens the full text when truncated, rather than expanding in place and pushing
/// the artwork around.
///
/// On tvOS it always takes focus (below the action row): Down from Play lands here,
/// Up from here returns to Play, and Up from Play — with nothing above — opens the
/// fullscreen trailer. Off tvOS it is only a button when there is more to read.
struct MediaItemPlotView: View {

  let title: String
  let plot: String
  /// Shared with the other hero controls so focusing the plot does not count as
  /// leaving the hero (and killing the trailer).
  @FocusState.Binding var focus: MediaItemFocusTarget?

  /// The two heights the truncation decision is made from, kept as state so it is
  /// remade every time the layout changes — the old `ViewThatFits` probe latched
  /// `isTruncated` to true in an `onAppear` that fired once and never reset, so a
  /// paragraph that fit still wore a "More" once the real plot replaced the mock, or
  /// once a wider layout un-clipped it. Measuring both heights on every pass instead
  /// lets the answer go back to false when the text genuinely fits.
  @State private var fullHeight: CGFloat = 0
  @State private var clampedHeight: CGFloat = 0
  @State private var showsFullText = false

  /// The full copy needs more room than the clamped three lines leave it. A point of
  /// slack absorbs sub-pixel rounding so a paragraph that exactly fills the clamp is
  /// not called truncated. Both heights start at zero, so until the first measurement
  /// lands this reads false — the page opens without a "More" that then vanishes,
  /// rather than the other way round.
  private var isTruncated: Bool {
    fullHeight > 0 && clampedHeight > 0 && fullHeight > clampedHeight + 1
  }

  var body: some View {
    content
      .frame(maxWidth: Self.maxWidth, alignment: .leading)
      // Measured whichever branch is showing, so the decision keeps up with the plot
      // changing and with the frame it is laid out in.
      .onPreferenceChange(PlotClampedHeightKey.self) { clampedHeight = $0 }
      .onPreferenceChange(PlotFullHeightKey.self) { fullHeight = $0 }
  }

  @ViewBuilder
  private var content: some View {
#if os(tvOS)
    Button {
      if isTruncated { showsFullText = true }
    } label: {
      paragraph(showsMore: isTruncated)
    }
    .buttonStyle(ExpandableButtonStyle())
    .focused($focus, equals: .plot)
    .sheet(isPresented: $showsFullText) {
      plotSheet
    }
#else
    if isTruncated {
      Button {
        showsFullText = true
      } label: {
        paragraph(showsMore: true)
      }
      .buttonStyle(ExpandableButtonStyle())
      .focused($focus, equals: .heroOther)
      .sheet(isPresented: $showsFullText) {
        plotSheet
      }
    } else {
      paragraph(showsMore: false)
    }
#endif
  }

  private var plotSheet: some View {
    MediaItemDetailSheet(title: Text(title)) {
      Text(plot)
        .font(MediaItemSheetLayout.bodyFont)
        .foregroundStyle(Color.white)
        .multilineTextAlignment(.leading)
    }
  }

  private func paragraph(showsMore: Bool) -> some View {
    HStack(alignment: .lastTextBaseline, spacing: 14) {
      Text(plot)
        .font(Self.font)
        .foregroundStyle(Color.white)
        .lineLimit(Self.lineLimit)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The clamped text reports its own drawn height, and the same copy is measured
        // unclamped in the same width beside it. Both are backgrounds of the visible
        // line, so both are proposed the width it actually got — the width already
        // narrowed by the "More" label when one is shown.
        .background {
          GeometryReader { geometry in
            Color.clear.preference(key: PlotClampedHeightKey.self, value: geometry.size.height)
          }
        }
        .background {
          Text(plot)
            .font(Self.font)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
              GeometryReader { geometry in
                Color.clear.preference(key: PlotFullHeightKey.self, value: geometry.size.height)
              }
            }
            .hidden()
        }

      // Only laid out when shown: with the plot fitting there is nothing more to read,
      // so the label is gone rather than reserved-and-invisible — its width no longer
      // narrows a paragraph that has room to spare. The whole synopsis control opens
      // the sheet; this label is a hint, not a second button.
      if showsMore {
        Text("More")
          .font(Self.moreFont.weight(.semibold))
          .textCase(.uppercase)
          .tracking(Self.moreTracking)
          .opacity(Self.moreOpacity)
          .fixedSize()
          .accessibilityHidden(true)
      }
    }
  }

  /// A step below the paragraph, so it reads as a hint rather than as a fourth line.
  static let moreOpacity: Double = 0.65

  /// System text styles rather than hand-picked point sizes: the synopsis sits next
  /// to real tvOS controls and has to be on the same scale they are. A step below the
  /// metadata line above it, and the label a step below that again.
  static let font: Font = .caption
  static let moreFont: Font = .caption2

#if os(tvOS)
  static let lineLimit = 4
  /// Parent hero column caps width; this is the soft ceiling inside the centre column.
  static let maxWidth: CGFloat = 560
  static let moreTracking: CGFloat = 1
#else
  static let lineLimit = 4
  static let maxWidth: CGFloat = 420
  static let moreTracking: CGFloat = 0.8
#endif
}

/// Anything on this page that can be opened in full: the synopsis and the info
/// columns. Secondary at rest so it sits behind the title and buttons, solid and
/// backed once focused (or hovered on pointer platforms) so it reads as the control
/// it is. Text that sets its own colour — the columns do — keeps it and picks up
/// only the highlight.
///
/// Pass `showsPointerHighlight: false` for Information/Languages blocks whose
/// *inner* rows are already links — a whole-column hover plate would mislead.
private struct ExpandableButtonStyle: ButtonStyle {
  var showsPointerHighlight: Bool = true

  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    // Not named `Body`: that collides with `ButtonStyle.Body`.
    ExpandableLabel(configuration: configuration,
                    showsPointerHighlight: showsPointerHighlight)
  }

  private struct ExpandableLabel: View {
    let configuration: ButtonStyleConfiguration
    let showsPointerHighlight: Bool
    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false

    private var isHighlighted: Bool {
#if os(tvOS)
      isFocused
#else
      isFocused || (showsPointerHighlight && isHovered)
#endif
    }

    var body: some View {
      configuration.label
        // At rest this is a step down from the title, not the full 40% fade of the
        // subtitle colour: the synopsis sits over artwork now, and at 0.6 it went
        // soft against a bright frame.
        .foregroundStyle(isHighlighted ? Color.KinoPub.text : Color.KinoPub.text.opacity(0.8))
        // Inset whether or not it is focused and then pulled back out again: making
        // the padding appear on focus kept the frame the same width and re-wrapped
        // the paragraph inside it. The highlight bleeds into the surrounding gaps
        // instead, which is what it does on tvOS anyway.
        .padding(.horizontal, Self.horizontalInset)
        .padding(.vertical, Self.verticalInset)
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.KinoPub.selectionBackground.opacity(isHighlighted ? 0.85 : 0))
        )
        .padding(.horizontal, -Self.horizontalInset)
        .padding(.vertical, -Self.verticalInset)
        .scaleEffect(configuration.isPressed && showsPointerHighlight ? 0.98 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHighlighted)
        .animation(.spring(response: 0.15, dampingFraction: 0.9), value: configuration.isPressed)
#if !os(tvOS)
        .onHover { if showsPointerHighlight { isHovered = $0 } }
        .pointingHandCursorOnHover(enabled: showsPointerHighlight)
#endif
    }

#if os(tvOS)
    static let horizontalInset: CGFloat = 16
    static let verticalInset: CGFloat = 8
#else
    static let horizontalInset: CGFloat = 10
    static let verticalInset: CGFloat = 6
#endif
  }
}


/// Whatever was clipped on the page, presented over it in full: the synopsis, or a
/// column with its lists unclamped.
private struct MediaItemDetailSheet<Content: View>: View {

  let title: Text
  @ViewBuilder let content: () -> Content

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      Color.KinoPub.background.ignoresSafeArea()

      ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 24) {
          title
            .font(MediaItemSheetLayout.titleFont)
            .foregroundStyle(Color.KinoPub.text)

          content()

#if !os(tvOS)
          Button("Close") { dismiss() }
            .buttonStyle(.bordered)
#endif
        }
        .frame(maxWidth: MediaItemSheetLayout.maxWidth, alignment: .leading)
        .padding(MediaItemSheetLayout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      // Nothing in here is a control, and on tvOS a scroll view with nothing
      // focusable inside it will not move. This lets the remote pan it directly.
#if os(tvOS)
      .focusable()
#endif
    }
  }
}

/// Its own type because the sheet is generic over its content, and generic types
/// cannot hold static storage.
private enum MediaItemSheetLayout {
#if os(tvOS)
  static let titleFont: Font = .system(size: 48, weight: .bold)
  static let bodyFont: Font = .system(size: 30, weight: .regular)
  static let captionFont: Font = .system(size: 28, weight: .regular)
  static let maxWidth: CGFloat = 1200
  static let padding: CGFloat = 80
#else
  static let titleFont: Font = .system(size: 26, weight: .bold)
  static let bodyFont: Font = .system(size: 16, weight: .regular)
  static let captionFont: Font = .system(size: 14, weight: .regular)
  static let maxWidth: CGFloat = 640
  static let padding: CGFloat = 24
#endif
}

#if DEBUG
private struct PlotPreviewHost: View {
  @FocusState private var focus: MediaItemFocusTarget?

  var body: some View {
    MediaItemPlotView(
      title: "Стражи Галактики",
      plot: MediaItem.mock().plot,
      focus: $focus
    )
    .padding()
    .frame(maxWidth: 560, alignment: .leading)
    .background(Color.black)
    .preferredColorScheme(.dark)
  }
}

#Preview("Synopsis More") {
  PlotPreviewHost()
}

#Preview("Hero badge strip") {
  HStack(spacing: 16) {
    Text("2023 · 2 h 30 min · США")
    MediaScoresView(imdb: 8.1, kinopoisk: 8.3)
    MediaCapabilityBadgesView(
      badges: MediaCapabilityBadges(
        is4K: true,
        isHDR: true,
        ageRating: "16+",
        hasClosedCaptions: true,
        audioChannelHint: "DD"
      ),
      mode: .detail
    )
  }
  .font(.subheadline)
  .foregroundStyle(.white.opacity(0.85))
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
#endif
