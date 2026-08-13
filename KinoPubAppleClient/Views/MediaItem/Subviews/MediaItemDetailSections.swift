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
    /// Nil when the source has voters but has not published a score yet — Kinopoisk
    /// counts votes long before it prints a number.
    let value: Double?
    let votes: Int?
  }

  private var aggregate: Rating? {
    guard FeatureFlags.combinedRatingEnabled else { return nil }
    return MediaScores(mediaItem).aggregate
  }

  private var aggregateVotes: Int {
    MediaScores(mediaItem).totalVotes
  }

  private var scores: [Score] {
    let bundle = MediaScores(mediaItem)
    return [
      Self.score(id: "IMDb", logo: .imdb, value: bundle.imdb, votes: bundle.imdbVotes),
      Self.score(id: "Кинопоиск",
                 logo: .kinopoisk,
                 value: bundle.kinopoisk,
                 votes: bundle.kinopoiskVotes)
    ].compactMap { $0 }
  }

  /// A source earns a tile once it has *either* a score or voters. Votes without a
  /// score is Kinopoisk's "недостаточно оценок" state — worth showing as a dash and a
  /// note rather than pretending the source has nothing.
  private static func score(id: String,
                            logo: MediaScoreLogo.Source,
                            value: Double?,
                            votes: Int?) -> Score? {
    let isRated = (value ?? 0) > 0
    let hasVoters = (votes ?? 0) > 0
    guard isRated || hasVoters else { return nil }
    return Score(id: id, logo: logo, value: isRated ? value : nil, votes: votes)
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

        // Tiles keep their natural width and the row scrolls, like every other
        // section — squeezing three of them into the page width wrapped "Кинопоиск"
        // mid-word and split the view count across two lines.
        ScrollView(.horizontal, showsIndicators: false) {
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
#if os(tvOS)
          // Slack for the focus-scale grow, so a focused tile is not clipped by the
          // section above/below it.
          .padding(.vertical, DetailTileStyle.focusPadding)
#endif
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
#if os(tvOS)
        .scrollClipDisabled()
//        .focusSection()
#endif
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
  static let titleFont: Font = TypeScale.detailBody
static let captionFont: Font = .caption
#else
  static let spacing: CGFloat = 12
  static let tilePadding: CGFloat = 14
  static let iconSize: CGFloat = 32
  static let valueFont: Font = .system(size: 32, weight: .semibold, design: .rounded)
  static let titleFont: Font = .system(size: 14, weight: .semibold)
    static let captionFont: Font = TypeScale.detailBody

#endif

  /// Vote counts and source notes — the page's one running-text size.
}

private struct AggregateRatingTile: View {
  let rating: Rating
  let votes: Int
  var onSectionFocused: (() -> Void)? = nil
  var pageEntryFocus: FocusState<MediaItemFocusTarget?>.Binding? = nil
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
#if os(tvOS)
    // A focus stop rather than an action, but it is still a `Button` — that is how the
    // system card style is reached, and how Apple's own sample makes everything
    // focusable. Selecting it deliberately does nothing (yet).
    Button {} label: { content }
      .buttonStyle(DetailTileStyle.buttonStyle)
      .modifier(OptionalPageEntryFocus(binding: pageEntryFocus))
      .reportMediaItemSectionFocus(onSectionFocused)
#else
    content
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
//            .(horizontal: , vertical: true)
        }
      }
    }
    .padding(MediaItemRatingsSection.tilePadding)
//    .background(
//      Color.KinoPub.selectionBackground.opacity(0.5),
//      in: RoundedRectangle(cornerRadius: 14, style: .continuous)
//    )
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
    .buttonStyle(DetailTileStyle.buttonStyle)
#if os(tvOS)
    .modifier(OptionalPageEntryFocus(binding: pageEntryFocus))
    .reportMediaItemSectionFocus(onSectionFocused)
#else
    .onHover { isHovered = $0 }
    .pointingHandCursorOnHover(enabled: isLink)
#endif
  }

  private var tileContent: some View {
    HStack(alignment: .center, spacing: 10) {
      MediaScoreLogo(score.logo, height: MediaItemRatingsSection.iconSize, style: .color)
        .frame(width: MediaItemRatingsSection.iconSize, height: MediaItemRatingsSection.iconSize)

      Text(score.value.map { String(format: "%.1f", $0) } ?? "—")
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
        // Voters but no score yet — say so the way the source itself does, rather
        // than printing a count next to a dash and leaving it unexplained.
        if score.value == nil {
          Text("MediaItem_NotEnoughRatings")
            .font(MediaItemRatingsSection.captionFont)
            .foregroundStyle(Color.KinoPub.subtitle)
            .fixedSize(horizontal: false, vertical: true)
        } else if let votes = score.votes, votes > 0 {
          Text("\(votes.formatted(.number.grouping(.automatic))) \("votes".localized)")
            .font(MediaItemRatingsSection.captionFont)
            .foregroundStyle(Color.KinoPub.subtitle)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(MediaItemRatingsSection.tilePadding)
//    .background(
//      Color.KinoPub.selectionBackground.opacity(isLink && isHovered ? 0.72 : 0.5),
//      in: RoundedRectangle(cornerRadius: 14, style: .continuous)
//    )
//    .animation(.easeOut(duration: 0.15), value: isHovered)
  }
}

private struct ViewsRatingTile: View {
  let views: Int
  var onSectionFocused: (() -> Void)? = nil
  var pageEntryFocus: FocusState<MediaItemFocusTarget?>.Binding? = nil

  var body: some View {
#if os(tvOS)
    // Same as `AggregateRatingTile`: a focus stop expressed as a `Button` so it can wear <<<< it must be interactive and all platforms as well not just here
    // the system card style.
    Button {} label: { content }
      .buttonStyle(DetailTileStyle.buttonStyle)
      .modifier(OptionalPageEntryFocus(binding: pageEntryFocus))
      .reportMediaItemSectionFocus(onSectionFocused)
#else
    content
#endif
  }

  private var content: some View {
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

/// The detail page's tile-shaped controls (rating tiles, vote pills) on tvOS.
///
/// **`.card` and nothing else.** This is the system card style — Apple's own `DestinationVideo`
/// sample applies exactly `#if os(tvOS) .card #else .plain` to every focusable card in the app and
/// adds no focus code of its own (`.hoverEffect()` there is fenced to iOS/visionOS). Focus scale,
/// highlight, lift and parallax are all system-owned; hand-rolling them is what produced the two
/// bugs before this: `.hoverEffect(.highlight)` lit up the icon alone (the tvOS highlight attaches
/// to the first `Image` in the label), and the custom `scaleEffect`/`brightness` replacement that
/// followed was correct-ish but visibly not native.
///
/// Do not add `hoverEffect`, `scaleEffect`, `brightness` or `isFocused` branches on top of this.
enum DetailTileStyle {
  static var buttonStyle: some PrimitiveButtonStyle {
#if os(tvOS)
    .card
#else
    .plain
#endif
  }

  /// Slack a row reserves so the card's focus lift is not clipped by its neighbours.
#if os(tvOS)
  static let focusPadding: CGFloat = 24
#else
  static let focusPadding: CGFloat = 0
#endif
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
  var onSectionFocused: (() -> Void)? = nil

#if os(tvOS)
  /// The UIKit rail can't use a SwiftUI `NavigationLink`, so selection is pushed
  /// through the same environment hook `MediaPosterShelf`'s TVUIKit rails use.
  @Environment(\.mediaNavigation) private var mediaNavigation
#endif

  /// Pushbr is not a last resort here, it is the *working* source, and waiting on TMDB
  /// before asking for it left every face a monogram.
  ///
  /// `TitleMetadata.enrich` matches credits by normalized name, and normalizing only
  /// folds diacritics — kino.pub returns "Реми Безансон" where TMDB returns
  /// "Rémi Bezançon", so the two never meet and `photo` stays nil however many photos
  /// the payload carried. Pushbr is keyed by the MD5 of the *kino.pub* name, which is
  /// exactly what we hold, so it resolves on the first frame with no metadata at all.
  /// This is what the person page has always done — see `PersonItemsView.hero`.
  ///
  /// The old ordering existed to avoid painting pushbr and then swapping to a sharper
  /// TMDB copy. That swap is now free: `TVUIKitRemoteImage` keeps both decoded, so the
  /// upgrade is a repaint rather than a blink back to initials.
  private func photoURL(for member: CastMember) -> URL? {
    member.photo ?? ActorImageProvider.photoURL(for: member.name)
  }

  private var people: [(person: MediaPerson, member: CastMember)] {
    let directors = TitleMetadata.enrich(
      names: mediaItem.directorNames,
      roleDepartment: "Directing",
      from: externalMetadata
    ).map {
      (MediaPerson(name: $0.name,
                   role: .director,
                   photoURL: photoURL(for: $0),
                   tmdbPersonId: $0.tmdbPersonId), $0)
    }
    let actors = TitleMetadata.enrich(
      names: mediaItem.castMembers,
      roleDepartment: "Acting",
      from: externalMetadata
    ).map {
      (MediaPerson(name: $0.name,
                   role: .actor,
                   photoURL: photoURL(for: $0),
                   tmdbPersonId: $0.tmdbPersonId), $0)
    }
    return directors + actors
  }

  var body: some View {
    if !people.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("Cast & Crew")

#if os(tvOS)
        monogramRail
#else
        portraitRail
#endif
      }
    }
  }

#if os(tvOS)
  /// System `TVMonogramContentConfiguration` circles — the round person treatment
  /// Apple's own tvOS apps use, and the shape TVUIKit draws for people. Replaces a
  /// hand-rolled rounded-rect avatar + `PortraitButtonStyle` (manual `scaleEffect`,
  /// and — until the 2026-08-09 shadow pass — a focus-animated `shadow` radius on
  /// every visible circle). The system cell owns its focus motion, so there is no
  /// custom focus code left on this rail at all.
  ///
  /// Two things the SwiftUI rail had and this does not: `mediaZoomSource` (the zoom
  /// transition is a SwiftUI-`NavigationLink` affordance with no UIKit-cell analog
  /// here) and per-card `reportMediaItemSectionFocus`; the wash now flips from this
  /// section's own `.detailFocusSection()` wrapper at the page level instead.
  private var monogramRail: some View {
    TVUIKitPersonCollection(
      people: people.map { entry in
        TVUIKitPerson(id: entry.person.id,
                      name: entry.person.name,
                      nameComponents: TVUIKitPerson.nameComponents(from: entry.person.name),
                      caption: Self.caption(for: entry),
                      photoURL: entry.person.photoURL)
      },
      onSelect: { person in
        guard let entry = people.first(where: { $0.person.id == person.id }) else { return }
        mediaNavigation?(linkProvider.person(for: entry.person))
      },
      onCellFocused: onSectionFocused
    )
    .frame(height: TVUIKitPersonCollectionController.railHeight)
//    .focusSection()
  }

  /// Character when TMDB has one, else the credit role — same rule as
  /// `CastPortraitView.subtitleLabel`, which still backs the non-tvOS rail.
  private static func caption(for entry: (person: MediaPerson, member: CastMember)) -> String {
    if let character = entry.member.character?.trimmingCharacters(in: .whitespacesAndNewlines),
       !character.isEmpty {
      return character
    }
    return entry.person.role.titleKey.localized
  }

#else
  private var portraitRail: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(alignment: .top, spacing: Self.spacing) {
        ForEach(people, id: \.person.id) { entry in
          NavigationLink(value: linkProvider.person(for: entry.person)) {
            CastPortraitView(person: entry.person, member: entry.member)
          }
          .mediaZoomSource(id: "person-\(entry.person.id)")
          .buttonStyle(PortraitButtonStyle())
        }
      }
      .padding(.horizontal, MediaItemLayout.horizontalInset)
      .padding(.vertical, Self.focusPadding)
    }
  }
#endif

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
  @Environment(\.openURL) private var openURL
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
    .kinoGlassRim(in: Self.posterShape)
    .animation(.easeOut(duration: 0.2), value: image == nil)
    .modifier(MediaCardContextMenuModifier(entries: debugMenuEntries))
    .task(id: loadKey) {
      await loadPhoto()
    }
  }

  private var debugMenuEntries: [MediaCardContextEntry] {
    MediaCardContextMenus.debugImageEntries(
      urls: [photoURL].compactMap { $0 },
      openURL: { openURL($0) }
    )
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
        .foregroundStyle(Color.KinoPub.subtitle)
    }
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
#if !os(tvOS)
        // Radius (not just opacity) changes with focus — SwiftUI has to re-render the
        // shadow's blur every tick, on every cast/crew circle in the row. Off on tvOS,
        // where this style backs a `LazyHGrid` of many simultaneously-visible circles.
        .shadow(color: .black.opacity(isFocused ? 0.45 : (isHovered ? 0.2 : 0)),
                radius: isFocused ? 14 : 8,
                y: isFocused ? 6 : 2)
#endif
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

// MARK: - Related rows (Similar / More from director / More with actor)

/// The related-item shelves, unified: one `[MediaRow]` (built by
/// `MediaItemModel.relatedRows`) rendered through the exact same `MediaPosterShelf`
/// Home's rows use, sharing ONE `@FocusState` across all of them — a card focused in
/// "Similar" and one focused in "More from <director>" now behave exactly like two
/// rows on the Home screen, restoring focus the same way, instead of being three
/// independently-wired shelves each with its own focus/menu state (which is what
/// this replaces — see `MediaItemPosterShelf`'s prior per-instance
/// `MediaCardMenuCoordinator`, now owned once by the page and passed in).
///
/// Deliberately does NOT use `KinoPubUI`'s `MediaRowsView`: that component wraps its
/// own vertical `ScrollView`, built to be an entire page's content (Home, Library,
/// Bookmarks), not a fragment embedded in another page. Nesting a second vertical
/// `ScrollView` inside this page's own would double up scroll/focus capture on tvOS
/// — the same class of bug that broke navigation when phase 1 of
/// `docs/archive/plans/detail-page-choreography.md` pulled the hero into a `ZStack`
/// sibling. This reproduces `MediaRowsView`'s per-row rendering and shared
/// `@FocusState` directly, without its outer scroll container.
struct MediaItemRelatedRowsSection: View {

  let rows: [MediaRow]
  let relatedItem: (Int) -> MediaItem?
  let linkProvider: NavigationLinkProvider
  let cardMenu: MediaCardMenuCoordinator
  /// Titles for shelves still loading — same skeleton, now interleaved in this one
  /// section instead of belonging to whichever standalone section it used to sit in.
  var pendingShelves: [String] = []
  var onSectionFocused: (() -> Void)? = nil

  @Environment(ErrorHandler.self) private var errorHandler
  @EnvironmentObject private var navigationState: NavigationState
  @Environment(\.openURL) private var openURL

  private struct CardKey: Hashable {
    let row: String
    let card: Int
  }

  @FocusState private var focusedCard: CardKey?

  var body: some View {
    if !rows.isEmpty || !pendingShelves.isEmpty {
      VStack(alignment: .leading, spacing: MediaItemLayout.sectionSpacing) {
        ForEach(rows) { row in
          MediaPosterShelf(
            title: row.title,
            count: row.count,
            cards: row.cards,
            destination: row.destination,
            navigationLinkProvider: { card in
              if let item = relatedItem(card.id) {
                return linkProvider.link(for: item)
              }
              // Defensive fallback only — every card here was built from an item in
              // `rows`, so the lookup above always succeeds in practice.
              return Route.detailsById(card.id)
            },
            contextMenuProvider: { card in
              MediaCardContextMenus.entries(for: card,
                                            surface: .shelf,
                                            menu: cardMenu,
                                            pushRoute: { navigationState.push($0) },
                                            openURL: { openURL($0) })
            },
            focusedCard: $focusedCard,
            focusKey: { CardKey(row: row.id, card: $0.id) },
            onCardFocused: onSectionFocused
          )
        }

        ForEach(pendingShelves, id: \.self) { title in
          MediaItemPosterShelfSkeleton(title: title)
        }
      }
      .task {
        cardMenu.bind(errorHandler: errorHandler)
        await cardMenu.refreshFolders()
      }
      .mediaCardNewFolderAlert(cardMenu)
    }
  }
}

/// Placeholder strip while a person shelf query is in flight — same column
/// metrics as the real rail so it doesn't jump when content arrives.
private struct MediaItemPosterShelfSkeleton: View {
  let title: String

  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var containerWidth: CGFloat = 1100

  private var metrics: ShelfMetrics {
    .posters(width: containerWidth, typeSize: typeSize)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: title)
        .safeAreaPadding(.horizontal, metrics.inset)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: metrics.gutter) {
          ForEach(0..<metrics.columns, id: \.self) { _ in
            RoundedRectangle(cornerRadius: MediaCardView.cornerRadius, style: .continuous)
              .fill(Color.KinoPub.selectionBackground.opacity(0.45))
              .aspectRatio(CardAspect.poster.ratio, contentMode: .fit)
              .containerRelativeFrame(.horizontal,
                                      count: metrics.columns,
                                      span: 1,
                                      spacing: metrics.gutter)
              .redacted(reason: .placeholder)
          }
        }
        .safeAreaPadding(.horizontal, metrics.inset)
        .padding(.vertical, Metrics.focusPadding)
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: { width in
      if width > 0 { containerWidth = width }
    }
  }
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
#if os(tvOS)
    // Slack for the focus-scale grow, same as the ratings row above.
    .padding(.vertical, DetailTileStyle.focusPadding)
#endif
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
    .buttonStyle(DetailTileStyle.buttonStyle)
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

  /// The strip above the table: what this title **is** and where it comes from —
  /// type, country, genre. These are the only information values that ever led
  /// somewhere (a filtered search), and as table rows they were both buried and, on
  /// tvOS, a row of individually-focusable links the remote had to crawl through one
  /// at a time. As tags they read as one breadcrumb-ish line and are a single focus
  /// group. Studios / production companies belong here too when we carry them.
  ///
  /// Values with no filter (a subtype kino.pub has no query for) still render — as
  /// plain, unfocusable capsules — so the line reads the same whether or not every
  /// tag happens to be actionable.
  private var tagValues: [InfoValue] {
    var tags: [InfoValue] = [
      InfoValue(id: "type",
                title: mediaItem.contentTypeTitleKey.localized,
                filter: mediaItem.contentTypeFilter.map { LibraryFilter(contentType: $0) })
    ]
    if let subtypeKey = mediaItem.contentSubtypeTitleKey {
      tags.append(InfoValue(id: "subtype", title: subtypeKey.localized))
    } else if let raw = mediaItem.contentSubtypeRaw {
      tags.append(InfoValue(id: "subtype", title: raw))
    }

    tags.append(contentsOf: mediaItem.countries
      .filter { !$0.title.isEmpty }
      .map {
        InfoValue(id: "country-\($0.id)",
                  title: $0.title,
                  filter: LibraryFilter(countryID: $0.id))
      })

    tags.append(contentsOf: mediaItem.genres.compactMap { genre -> InfoValue? in
      guard let title = genre.title, !title.isEmpty else { return nil }
      return InfoValue(id: "genre-\(genre.id)",
                       title: title,
                       filter: LibraryFilter(genreID: genre.id))
    })

    return tags
  }

  /// Everything about *this release* that is not a date and not a tag. With type /
  /// country / genre gone to `tagValues`, nothing left in the table navigates — the
  /// whole block is now read-only text, which is why it no longer takes focus at all.
  private var detailsCardSections: [InfoSection] {
    var sections: [InfoSection] = []

    if let aka = mediaItem.alsoKnownAsTitle {
      sections.append(InfoSection(id: "aka",
                                  caption: "MediaItem_AlsoKnownAs",
                                  values: [InfoValue(id: "aka", title: aka)]))
    }

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
    sections.append(contentsOf: volumeSections)

    if !flagValues.isEmpty {
      sections.append(InfoSection(id: "flags",
                                  caption: "MediaItem_Flags",
                                  values: flagValues))
    }

    return sections
  }

  /// The table as cards rather than three long columns. Grouping is by the question
  /// each answers — when it came out, what this release is, how it plays — so a
  /// glance lands on the one that matters instead of scanning a wall of label/value
  /// pairs. Empty groups drop out entirely; languages is its own card below because
  /// it owns expansion state the others do not have.
  private var infoCards: [InfoCard] {
    var cards: [InfoCard] = []
    if !releaseCardSections.isEmpty {
      cards.append(InfoCard(id: "release", title: "MediaItem_Release", sections: releaseCardSections))
    }
    if !detailsCardSections.isEmpty {
      cards.append(InfoCard(id: "details", title: "Information", sections: detailsCardSections))
    }
    if !technicalSections.isEmpty {
      cards.append(InfoCard(id: "technical", title: "MediaItem_Technical", sections: technicalSections))
    }
    return cards
  }

  private struct InfoCard: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let sections: [InfoSection]
  }

  /// Release / expected release / season premiere / status — the date-driven block
  /// fed by TMDB air dates, with kino.pub's year as the final fallback. Season and
  /// episode totals moved to `volumeSections`.
  private var releaseCardSections: [InfoSection] {
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

    return sections
  }

  /// How much of the show exists and how much of it is here — series only. Split out
  /// of the release block: "18 seasons, 386 episodes" answers *how much is there*,
  /// not *when it came out*, and reads better next to the runtime than under a date.
  private var volumeSections: [InfoSection] {
    var sections: [InfoSection] = []

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

  private var showsLanguagesCard: Bool {
    !audioGroups.isEmpty || !subtitleGroups.isEmpty
  }

  @AppStorage(MediaItemAboutLayout.storageKey)
  private var layoutRaw = MediaItemAboutLayout.tiers.rawValue

  private var layout: MediaItemAboutLayout {
    MediaItemAboutLayout(rawValue: layoutRaw) ?? .tiers
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Self.footerSpacing) {
#if DEBUG
      // Cycles the four candidate compositions in place, so they can be compared on a
      // real title instead of in the abstract. Goes away with the losing three.
      AboutLayoutSwitcher(layout: layout) { next in
        layoutRaw = next.rawValue
      }
#endif

      if !tagValues.isEmpty {
        TagStrip(values: tagValues, onSectionFocused: onSectionFocused)
      }

      switch layout {
      case .appleShape: AboutLayoutAppleShape(content: aboutContent)
      case .legend: AboutLayoutLegend(content: aboutContent)
      case .tiers: AboutLayoutTiers(content: aboutContent)
      case .specSheet: AboutLayoutSpecSheet(content: aboutContent)
      }

      InfoFooter(mediaItem: mediaItem,
                 attribution: externalMetadata.attribution,
                 tmdbId: externalMetadata.tmdbId,
                 isSeries: mediaItem.isSeries,
                 debugLog: externalMetadata.debugLog,
                 onSectionFocused: onSectionFocused)
    }
    .padding(.horizontal, MediaItemLayout.horizontalInset)
  }

  /// One value the four layouts share, so switching between them can only change the
  /// composition — never which facts are on screen.
  private var aboutContent: MediaItemAboutContent {
    MediaItemAboutContent(
      synopsis: mediaItem.plot.isEmpty ? nil : mediaItem.plot,
      title: mediaItem.localizedTitle,
      primaryGenre: mediaItem.genres.compactMap(\.title).first,
      ageRating: externalMetadata.ageRating,
      advisories: advisories,
      tags: tagValues,
      releaseSections: releaseCardSections,
      detailSections: detailsCardSections,
      technicalSections: technicalSections,
      badges: aboutBadges,
      languageSummary: languageSummary,
      subtitleNames: subtitleGroups.map(\.name)
    )
  }

  private var advisories: [String] {
    var result: [String] = []
    if mediaItem.advert { result.append("MediaItem_ContainsAds".localized) }
    if mediaItem.poorQuality { result.append("MediaItem_PoorQuality".localized) }
    return result
  }

  /// The legend. Only badges we can actually justify from the payload — kino.pub
  /// carries no HDR / Dolby Vision flag, so those are absent rather than guessed.
  private var aboutBadges: [MediaItemAboutContent.AboutBadge] {
    var badges: [MediaItemAboutContent.AboutBadge] = []

    if let quality = mediaItem.qualityDisplay {
      badges.append(.init(id: "quality",
                          short: quality,
                          name: "MediaItem_VideoQuality".localized,
                          explanation: "MediaItem_LegendQuality".localized,
                          isProminent: true))
    }
    if let ac3 = mediaItem.ac3, ac3 > 0 {
      badges.append(.init(id: "ac3",
                          short: "AC3",
                          name: "MediaItem_AudioCodec".localized,
                          explanation: "MediaItem_LegendAC3".localized))
    }
    if !subtitleGroups.isEmpty {
      badges.append(.init(id: "cc",
                          short: "CC",
                          name: "Subtitles".localized,
                          explanation: "MediaItem_LegendCC".localized))
    }
    if mediaItem.detailAudioTracks.contains(where: \.isAudioDescription) {
      badges.append(.init(id: "ad",
                          short: "AD",
                          name: "MediaItem_LegendADName".localized,
                          explanation: "MediaItem_LegendAD".localized))
    }
    if let rating = externalMetadata.ageRating, !rating.isEmpty {
      badges.append(.init(id: "age",
                          short: rating,
                          name: "MediaItem_AgeRating".localized,
                          explanation: "MediaItem_LegendAgeRating".localized))
    }
    return badges
  }

  /// The viewer's own languages, in the order the system ranks them, each showing the
  /// best dub it has — "can I watch this", answered in two lines instead of a wall of
  /// every localization. Falls back to English, then to whatever the first (original)
  /// track is, when none of the preferred languages are present at all.
  private var languageSummary: [MediaItemAboutContent.LanguageLine] {
    var ordered: [MediaLanguageGroup] = []
    for key in preferredLanguages.map(SubtitleTracks.languageKey) {
      guard !ordered.contains(where: { $0.key == key }),
            let match = audioGroups.first(where: { $0.key == key }) else { continue }
      ordered.append(match)
    }
    if ordered.isEmpty {
      if let english = audioGroups.first(where: { $0.key == "en" }) {
        ordered.append(english)
      } else if let first = audioGroups.first {
        ordered.append(first)
      }
    }

    let subtitleKeys = Set(subtitleGroups.map(\.key))
    return ordered.prefix(3).map { group in
      MediaItemAboutContent.LanguageLine(
        id: group.key,
        language: group.name,
        best: group.detailLines.first,
        hasSubtitles: subtitleKeys.contains(group.key),
        extraCount: max(0, group.detailLines.count - 1)
      )
    }
  }

  // MARK: Tags

  /// Type · country · genre as one line of capsules, above the table. Each tag that
  /// has a filter opens Search on it — the same destination the table rows used to
  /// have, but reachable in one place instead of scattered through three columns.
  private struct TagStrip: View {
    let values: [InfoValue]
    var onSectionFocused: (() -> Void)? = nil
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
      // Wraps rather than scrolls: the whole set should be readable at a glance, and
      // a horizontally-scrolling strip would put tags off-screen with no hint.
      FlowLayout(spacing: MediaItemInfoColumns.tagSpacing) {
        ForEach(values) { value in
          if let filter = value.filter {
            Button {
              navigationState.openSearch(filter: filter, title: value.title)
            } label: {
              TagCapsule(title: value.title)
            }
            .buttonStyle(DetailTileStyle.buttonStyle)
          } else {
            // No query behind it — reads the same, simply isn't a control.
            TagCapsule(title: value.title)
          }
        }
      }
#if os(tvOS)
      .reportMediaItemSectionFocus(onSectionFocused)
//      .focusSection()
#endif
    }
  }

  /// Left-aligned wrapping row. SwiftUI has no built-in flow container — `HStack`
  /// would run off the edge and `LazyVGrid` would force a fixed column width that a
  /// mix of "USA" and "Science Fiction" cannot share.
  private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
      let maxWidth = proposal.width ?? .infinity
      var rowWidth: CGFloat = 0
      var rowHeight: CGFloat = 0
      var totalHeight: CGFloat = 0
      var widest: CGFloat = 0

      for subview in subviews {
        let size = subview.sizeThatFits(.unspecified)
        if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
          widest = max(widest, rowWidth)
          totalHeight += rowHeight + spacing
          rowWidth = size.width
          rowHeight = size.height
        } else {
          rowWidth += rowWidth > 0 ? spacing + size.width : size.width
          rowHeight = max(rowHeight, size.height)
        }
      }
      widest = max(widest, rowWidth)
      totalHeight += rowHeight
      return CGSize(width: min(widest, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
      var x = bounds.minX
      var y = bounds.minY
      var rowHeight: CGFloat = 0

      for subview in subviews {
        let size = subview.sizeThatFits(.unspecified)
        if x > bounds.minX, x + size.width > bounds.maxX {
          x = bounds.minX
          y += rowHeight + spacing
          rowHeight = 0
        }
        subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
        x += size.width + spacing
        rowHeight = max(rowHeight, size.height)
      }
    }
  }

  private struct TagCapsule: View {
    let title: String

    var body: some View {
      Text(title)
        .font(MediaItemInfoColumns.valueFont)
        .foregroundStyle(Color.KinoPub.text)
        .padding(.horizontal, MediaItemInfoColumns.tagHorizontalPadding)
        .padding(.vertical, MediaItemInfoColumns.tagVerticalPadding)
        .background(Capsule().fill(.thinMaterial))
    }
  }

  // MARK: Information cards

  /// One card of the information table. Purely presentational: with type / country /
  /// genre moved to `TagStrip`, nothing in here navigates, so it takes no focus and
  /// the remote skips straight past the whole block.
  private struct InfoCardView: View {
    let title: LocalizedStringKey
    let sections: [InfoSection]

    var body: some View {
      VStack(alignment: .leading, spacing: MediaItemInfoColumns.sectionSpacing) {
        Text(title)
          .font(MediaItemInfoColumns.cardTitleFont)
          .foregroundStyle(.secondary)

        ForEach(sections) { section in
          sectionBlock(section)
        }
      }
      .padding(MediaItemInfoColumns.cardPadding)
      // Equal share of the row — cards fill the page width instead of stacking to
      // the left at a fixed width.
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: MediaItemInfoColumns.cardCornerRadius, style: .continuous)
          .fill(.thinMaterial)
      }
    }

    @ViewBuilder
    private func sectionBlock(_ section: InfoSection) -> some View {
      VStack(alignment: .leading, spacing: MediaItemInfoColumns.stackSpacing) {
        Text(LocalizedStringKey(section.caption))
          .font(MediaItemInfoColumns.captionFont)
          .foregroundStyle(Color.KinoPub.subtitle)

        ForEach(section.values) { value in
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

  // MARK: Languages

  /// Audio and subtitles, shortest-useful-answer first: per language only the **best**
  /// dub available (`AudioTracks` orders kinds DUB → MVO → DVO → VO → AVO → Orig, so
  /// that is simply the first summary line), with the rest folded into a "+N" until
  /// the card is opened. A title with a proper dub and eight single-voice
  /// localizations should say "Russian · Dubbed", not list all nine.
  private struct LanguagesCard: View {
    let audioGroups: [MediaLanguageGroup]
    let subtitleGroups: [MediaLanguageGroup]
    let preferredLanguages: [String]
    var onSectionFocused: (() -> Void)? = nil

    @State private var showsAllAudio = false
    @State private var showsAllSubtitles = false

    /// Expanding shows every language *and* every dub kind within each language.
    private var isExpanded: Bool { showsAllAudio && showsAllSubtitles }

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

    /// Dub kinds hidden by the collapsed view, across every visible language.
    private var hiddenKindCount: Int {
      audioPartition.visible.reduce(0) { $0 + max(0, $1.detailLines.count - 1) }
    }

    private var canExpand: Bool {
      guard !isExpanded else { return false }
      return collapsedAudio.hiddenCount >= 2
        || collapsedSubtitles.hiddenCount >= 2
        || hiddenKindCount > 0
    }

    var body: some View {
      Button {
        guard canExpand else { return }
        showsAllAudio = true
        showsAllSubtitles = true
      } label: {
        VStack(alignment: .leading, spacing: MediaItemInfoColumns.sectionSpacing) {
          Text("Languages")
            .font(MediaItemInfoColumns.cardTitleFont)
            .foregroundStyle(.secondary)

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
        .padding(MediaItemInfoColumns.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
          RoundedRectangle(cornerRadius: MediaItemInfoColumns.cardCornerRadius, style: .continuous)
            .fill(.thinMaterial)
        }
      }
      .buttonStyle(DetailTileStyle.buttonStyle)
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
            // Collapsed: the best kind only (the list is already ranked, so that is
            // line 0). Expanded: every kind this language has.
            let lines = isExpanded ? group.detailLines : Array(group.detailLines.prefix(1))
            VStack(alignment: .leading, spacing: MediaItemInfoColumns.languageNameToKindSpacing) {
              Text(group.name)
                .font(MediaItemInfoColumns.valueFont)
                .foregroundStyle(Color.KinoPub.text)
              ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                  .font(MediaItemInfoColumns.detailFont)
                  .foregroundStyle(Color.KinoPub.text)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          }
        }

        // One count for both kinds of "there is more here" — extra languages and the
        // extra dubs folded away inside the ones on screen.
        let hidden = moreCount + hiddenKindCount
        if hidden > 0, !isExpanded {
          moreLabel(hidden)
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

  /// Dev-facing MetadataReferenceSection removed from the shipped footer (focus /
  /// bottom clutter). Restore from git history under this type if an API audit needs it.

#if os(tvOS)
  static let columnSpacing: CGFloat = 60
  static let sectionSpacing: CGFloat = 22
  static let languageGroupSpacing: CGFloat = 12
  static let languageNameToKindSpacing: CGFloat = 3
  static let subtitleExtraTop: CGFloat = 8
  static let stackSpacing: CGFloat = 4
  static let footerSpacing: CGFloat = 28
  static let cardPadding: CGFloat = 32
  static let cardCornerRadius: CGFloat = 24
  static let tagSpacing: CGFloat = 12
  static let tagHorizontalPadding: CGFloat = 22
  static let tagVerticalPadding: CGFloat = 12
#else
  static let columnSpacing: CGFloat = 28
  static let sectionSpacing: CGFloat = 16
  static let languageGroupSpacing: CGFloat = 8
  static let languageNameToKindSpacing: CGFloat = 1
  static let subtitleExtraTop: CGFloat = 8
  static let stackSpacing: CGFloat = 2
  static let footerSpacing: CGFloat = 20
  static let cardPadding: CGFloat = 16
  static let cardCornerRadius: CGFloat = 14
  static let tagSpacing: CGFloat = 8
  static let tagHorizontalPadding: CGFloat = 12
  static let tagVerticalPadding: CGFloat = 6
#endif

  /// Card titles inside the information table. Deliberately **not** `SectionHeader`:
  /// that is the page's *section* header — the thing that can carry a count, a
  /// chevron and a `NavigationLink` to a whole screen. What is inside the table is
  /// table chrome, and borrowing the section header here would advertise an
  /// affordance these titles do not have.
  static let cardTitleFont: Font = TypeScale.detailSection

  /// Captions and values differ by weight, not by size — the size is the page's one
  /// running-text token, shared with the hero and the rating captions.
  static let captionFont: Font = TypeScale.detailBody
  static let valueFont: Font = TypeScale.detailBody.weight(.medium)
  static let plainValueFont: Font = TypeScale.detailBody
  static let detailFont: Font = TypeScale.detailBody
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

  // No `headerFont` here (nor on `MediaItemInfoColumns`): every section title on this
  // page goes through `SectionHeader`, which owns the font and the vibrant-secondary
  // treatment. Both constants were three hand-picked point sizes that had already
  // drifted from `TypeScale.rowHeader` — the token the shared header actually uses.

#if os(tvOS)
  static let horizontalInset: CGFloat = 80
  static let sectionSpacing: CGFloat = 44
  /// Clears focus lift under the info panel + safe area.
  static let bottomPadding: CGFloat = 120
  /// Share of the viewport the hero occupies at rest — the remainder is the peek of
  /// the first section that says "there is more below". Expressed as a fraction, not
  /// a point inset, because that is the form Apple's tvOS layout guidance uses for a
  /// showcase header, and because it holds on any screen height rather than being
  /// tuned for one.
  static let heroFraction: CGFloat = 0.8
#elseif os(macOS)
  static let horizontalInset: CGFloat = 32
  static let sectionSpacing: CGFloat = 28
  static let bottomPadding: CGFloat = sectionSpacing
#else
  static let horizontalInset: CGFloat = 20
  static let sectionSpacing: CGFloat = 24
  static let bottomPadding: CGFloat = sectionSpacing
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

  /// Always the control, on every platform — the synopsis is the canonical "there is
  /// more of this" surface, so it always opens rather than only when the clamp bit. It
  /// used to be a dead press on tvOS whenever the text happened to fit, and plain
  /// unfocusable copy off tvOS, which meant the same paragraph behaved two ways for a
  /// reason the reader cannot see. The "More" hint still depends on truncation: that is
  /// a statement about the text, not about whether the control exists.
  private var content: some View {
    paragraph(showsMore: isTruncated)
      .expandsIntoInfoPopup(title: Text(title)) {
        Text(plot)
          .font(InfoPopupMetrics.bodyFont)
          .foregroundStyle(Color.KinoPub.text)
          .multilineTextAlignment(.leading)
      }
      .focused($focus, equals: .plot)
  }

  private func paragraph(showsMore: Bool) -> some View {
    HStack(alignment: .lastTextBaseline, spacing: 14) {
      Text(plot)
        .font(Self.font)
        .foregroundStyle(Color.KinoPub.text)
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
          .accessibilityHidden(true)
      }
    }
  }

  /// A step below the paragraph, so it reads as a hint rather than as a fourth line.
  static let moreOpacity: Double = 0.65

  /// System text styles rather than hand-picked point sizes: the synopsis sits next
  /// to real tvOS controls and has to be on the same scale they are. The label is a
  /// step below the paragraph.
  static let moreFont: Font = .footnote

#if os(tvOS)
  static let lineLimit = 5
  /// Fills its column: the hero's written column already caps the width, and a
  /// second, narrower ceiling here left the synopsis short of the lines beneath it.
  static let maxWidth: CGFloat = .infinity
  static let moreTracking: CGFloat = 1
#else
  static let lineLimit = 4
  static let maxWidth: CGFloat = .infinity
  static let moreTracking: CGFloat = 0.8
#endif

  /// Same size as the metadata line above it and the information table below it.
  static let font: Font = TypeScale.detailBody
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
                .frame(maxWidth: 960, alignment: .leading)
                //    .background(Color.black)
                .preferredColorScheme(.dark)
            }
        }
        
        #Preview("Synopsis More") {
            PlotPreviewHost()
        }
        
        #Preview("Hero badge strip") {
            HStack(spacing: 16) {
                Text("2023,  South Korea")
                
                MediaScoresView(imdb: 8.1, kinopoisk: 8.3)
                // (countK) after score
                //      Text("2h 51m")
                Text("Comedy,  Drama")
                
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
            //  .foregroundStyle(.white.opacity(0.85))
            .padding()
            //  .background(Color.black)
            .preferredColorScheme(.dark)
        }
        
#endif
