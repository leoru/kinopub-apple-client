//
//  SeasonsRailView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Season tabs over one continuous horizontal rail of every episode in the series —
/// S1E1 through the finale — the way the Apple TV app presents a show. Tabs scroll the
/// rail to that season's first episode rather than swapping the content out. Opens
/// scrolled to the first unfinished episode.
///
/// Focus rules (tvOS): a full-width focus bridge sits between the season tabs and the
/// episode rail. Geometric Up from any episode always hits the bridge (not empty space
/// or a random tab); the bridge then hands focus to the *selected* season tab and
/// leaves the rail frozen. Down from a tab hits the same bridge and continues into
/// the rail. Left/Right on tabs still selects + scrolls when the season changes.
///
/// (`onMoveCommand` alone is not enough — the focus engine only forwards a move it
/// cannot resolve, so Up that geometrically finds Season 4 never reaches the handler.)
///
/// Section chrome (season tabs) stays hidden while the hero owns the page, so the
/// trailer/wide art isn't captioned by "Season 1" peeking under it; it fades in once
/// focus drops onto the rail and the backdrop blurs.
struct SeasonsRailView: View {

  let seasons: [Season]
  let linkProvider: NavigationLinkProvider
  /// Filled into every episode handed to the player, so its transport bar can show the
  /// series name rather than just the episode's own title.
  let seriesTitle: String
  /// False while the hero/trailer is up — season tabs stay out of the way.
  var showsChrome: Bool = true
  var onHide: ((Episode, Season) -> Void)?
  var onToggleWatched: ((Episode, Season) -> Void)?

  @State private var selectedSeasonID: Int?
  @State private var didScrollToUnseen = false
  /// True while a tab-driven scroll is in flight, so a stray episode focus update
  /// doesn't yank the selected tab back mid-jump.
  @State private var isScrollingFromTab = false
  /// Set while an episode holds focus, so the bridge knows Up-from-rail vs Down-from-tabs.
  @State private var episodeHadFocus = false
  @FocusState private var focusedSeasonID: Int?
  @FocusState private var focusedEpisodeID: Int?
#if os(tvOS)
  @FocusState private var bridgeFocused: Bool
  @Namespace private var seasonTabsScope
#endif

  private struct Entry: Identifiable {
    var id: Int { episode.id }
    let season: Season
    let episode: Episode
  }

  private var entries: [Entry] {
    seasons.flatMap { season in
      season.episodes.map { Entry(season: season, episode: $0) }
    }
  }

  private var selectedSeason: Season? {
    seasons.first { $0.id == selectedSeasonID } ?? seasons.first
  }

  /// First unfinished episode walking seasons in order, else the very first.
  private var firstUnseen: Entry? {
    entries.first { $0.episode.watched == 0 } ?? entries.first
  }

  /// Episode to land on when Down crosses the bridge from the season tabs.
  private var bridgeDownEpisodeID: Int? {
    if let selectedSeasonID,
       let first = seasons.first(where: { $0.id == selectedSeasonID })?.episodes.first {
      return first.id
    }
    return entries.first?.episode.id
  }

  var body: some View {
    ScrollViewReader { proxy in
      VStack(alignment: .leading, spacing: showsChrome ? 2 : 0) {
        if showsChrome {
          seasonTabs(proxy: proxy)
            .transition(.opacity)
#if os(tvOS)
          focusBridge
#endif
        }

        episodeRail
      }
      .animation(.easeOut(duration: 0.25), value: showsChrome)
      .onAppear {
        if selectedSeasonID == nil {
          selectedSeasonID = firstUnseen?.season.id ?? seasons.first?.id
        }
      }
      .task {
        await scrollToFirstUnseen(proxy: proxy)
      }
#if os(tvOS)
      .onChange(of: focusedSeasonID) { _, seasonID in
        // Left/Right onto a *different* tab selects + scrolls. Re-focusing the already
        // selected tab (Up via the bridge) leaves the rail frozen.
        guard let seasonID, seasonID != selectedSeasonID else { return }
        selectSeason(seasonID, proxy: proxy, animated: true)
      }
      .onChange(of: focusedEpisodeID) { _, episodeID in
        if episodeID != nil {
          episodeHadFocus = true
        }
        guard !isScrollingFromTab,
              let episodeID,
              let entry = entries.first(where: { $0.episode.id == episodeID }) else { return }
        selectedSeasonID = entry.season.id
      }
      .onChange(of: bridgeFocused) { _, focused in
        guard focused else { return }
        if episodeHadFocus {
          // Up from the rail → selected season tab, do not scroll.
          episodeHadFocus = false
          focusedSeasonID = selectedSeasonID ?? seasons.first?.id
        } else {
          // Down from the tabs → into the episode rail.
          focusedEpisodeID = bridgeDownEpisodeID
        }
      }
#endif
    }
  }

  // MARK: - Season tabs

  private func seasonTabs(proxy: ScrollViewProxy) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: Self.tabSpacing) {
        ForEach(seasons) { season in
          Button {
            // Enter / click only moves the rail when the season actually changes.
            guard season.id != selectedSeasonID else { return }
            selectSeason(season.id, proxy: proxy, animated: true)
          } label: {
            Text(Self.seasonTitle(season))
              .font(Self.tabFont)
          }
#if os(tvOS)
          .focused($focusedSeasonID, equals: season.id)
          .prefersDefaultFocus(season.id == selectedSeason?.id, in: seasonTabsScope)
#endif
          .buttonStyle(SeasonTabButtonStyle(isSelected: season.id == selectedSeason?.id))
        }
      }
      .padding(.horizontal, Self.horizontalInset)
//      .padding(.vertical, Self.focusPadding)
    }
#if os(tvOS)
    .focusScope(seasonTabsScope)
#endif
  }

#if os(tvOS)
  /// Full-width focus target between tabs and episodes. Geometry always finds this on
  /// Up from any card in the rail, so we never depend on a dead-end `onMoveCommand`.
  private var focusBridge: some View {
    Color.clear
      .frame(maxWidth: .infinity)
      .frame(height: 8)
      .focusable()
      .focused($bridgeFocused)
      .accessibilityHidden(true)
  }
#endif

  // MARK: - Episode rail

  private var episodeRail: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(alignment: .top, spacing: Self.cardSpacing) {
        ForEach(entries) { entry in
          let episode = entry.episode
          let season = entry.season
          let isFocusedEpisode = focusedEpisodeID == episode.id

          NavigationLink(value: linkProvider.player(for: filled(episode, in: season))) {
            EpisodeRailCard(episode: episode)
          }
          .buttonStyle(EpisodeCardButtonStyle())
#if os(tvOS)
          .focused($focusedEpisodeID, equals: episode.id)
#endif
          .modifier(MediaCardContextMenuModifier(
            actions: contextActions(for: episode, season: season)
          ))
          // Focused card paints above neighbours so scale + plate aren't shaved off.
          .zIndex(isFocusedEpisode ? 1 : 0)
          .id(Self.episodeAnchor(episode.id))
        }
      }
      .padding(.vertical, Self.focusPadding)
    }
    // Margins (not content padding): scrollTo(.leading) and focus scrolling keep the
    // left inset, so episode 1 isn't clipped flush against the screen edge.
    .contentMargins(.horizontal, Self.horizontalInset, for: .scrollContent)
    // Let focused cards grow (scale + multi-line titles) past the scroll view's bounds
    // instead of clipping the plate mid-caption.
    .scrollClipDisabled()
  }

  /// Selects a season and scrolls the episode rail to its first episode. Used by tab
  /// focus, tab activation, and the initial jump to the first unfinished episode.
  private func selectSeason(_ seasonID: Int, proxy: ScrollViewProxy, animated: Bool) {
    guard let season = seasons.first(where: { $0.id == seasonID }),
          let firstEpisode = season.episodes.first else { return }
    selectedSeasonID = seasonID
    let anchor = Self.episodeAnchor(firstEpisode.id)
    isScrollingFromTab = true
    if animated {
      withAnimation(.easeOut(duration: 0.2)) {
        proxy.scrollTo(anchor, anchor: .leading)
      }
    } else {
      proxy.scrollTo(anchor, anchor: .leading)
    }
    // Release the guard after the LazyHStack has had time to settle.
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(250))
      isScrollingFromTab = false
    }
  }

  private func scrollToFirstUnseen(proxy: ScrollViewProxy) async {
    guard !didScrollToUnseen, let target = firstUnseen else { return }
    didScrollToUnseen = true
    // LazyHStack needs a beat before the destination exists to scroll to.
    try? await Task.sleep(for: .milliseconds(120))
    guard !Task.isCancelled else { return }
    // Scroll only — don't claim focus. The page's defaultFocus stays on Play.
    selectSeason(target.season.id, proxy: proxy, animated: false)
  }

  private func contextActions(for episode: Episode, season: Season) -> [MediaCardContextAction] {
    let card = Self.contextCard(for: episode, in: season)
    return MediaCardContextMenus.actions(
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

  private static func contextCard(for episode: Episode, in season: Season) -> MediaCard {
    let progress: Double? = {
      guard episode.watched == 0, episode.duration > 0, episode.watching.time > 0 else { return nil }
      return min(Double(episode.watching.time) / Double(episode.duration), 1.0)
    }()
    return MediaCard(id: episode.id,
                     posterURL: episode.thumbnail,
                     title: episode.fixedTitle,
                     progress: progress,
                     landscapeImageURL: episode.thumbnail,
                     itemID: season.mediaId ?? episode.mediaId,
                     video: episode.number,
                     season: season.number,
                     mediaID: episode.id,
                     isWatched: episode.watched > 0,
                     isSeries: true)
  }

  private static func seasonTitle(_ season: Season) -> String {
    if season.title.isEmpty {
      return "\("Season".localized) \(season.number)"
    }
    return season.title
  }

  private static func episodeAnchor(_ id: Int) -> String { "episode-\(id)" }

#if os(tvOS)
  static let horizontalInset: CGFloat = 80
  static let cardSpacing: CGFloat = 36
  static let tabSpacing: CGFloat = 2
  static let focusPadding: CGFloat = 32
  static let tabFont: Font = .system(size: 36, weight: .bold)
#else
  static let horizontalInset: CGFloat = 20
  static let cardSpacing: CGFloat = 16
  static let tabSpacing: CGFloat = 8
  static let focusPadding: CGFloat = 6
  static let tabFont: Font = .system(size: 16, weight: .semibold)
#endif
}

// MARK: - Episode card

/// Fixed 16:9 still + permanent "EPISODE 9" label over a up-to-three-line title.
///
/// Ideally these would be `.fit` with every card sharing the height of the first
/// loaded still (frame == image, no crop, no letterbox). Until that uniform-height
/// pass exists, every card uses the same frame and `.fill`s — crop over broken layout.
///
/// Focus plate hugs the still + real caption (no empty 3-line slack inside the wash).
/// A hidden scaffold still reserves the full caption height in the rail so neighbours
/// don't reflow the section — plate and scale only wrap the content that exists.
private struct EpisodeRailCard: View {

  let episode: Episode
  @Environment(\.isFocused) private var isFocused

  private var episodeNumberLabel: String {
    "\("Episode".localized) \(episode.number)"
  }

  private var episodeTitle: String {
    episode.title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var progress: Double? {
    guard episode.watched == 0, episode.duration > 0, episode.watching.time > 0 else { return nil }
    return min(Double(episode.watching.time) / Double(episode.duration), 1.0)
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      // Invisible slot: still + max caption, keeps every card the same height in the rail.
      VStack(alignment: .leading, spacing: 2) {
        Color.clear
          .frame(width: Self.cardWidth, height: Self.stillHeight)
        captionReserve
          .padding(.horizontal, Self.captionPadding)
          .padding(.top, Self.captionSpacing)
          .padding(.bottom, Self.captionPadding)
      }
      .hidden()
      .accessibilityHidden(true)

      // Visible card: plate hugs this stack only.
      VStack(alignment: .leading, spacing: 2) {
        still
        caption
          .padding(.horizontal, Self.captionPadding)
          .padding(.top, Self.captionSpacing)
          .padding(.bottom, Self.captionPadding)
      }
      .background(
        RoundedRectangle(cornerRadius: Self.plateRadius, style: .continuous)
          .fill(isFocused ? Color.secondary.opacity(0.35) : Color.clear)
      )
      .scaleEffect(isFocused ? 1.05 : 1.0)
      .animation(.easeOut(duration: 0.2), value: isFocused)
    }
    .frame(width: Self.cardWidth, alignment: .topLeading)
  }

  /// Same structure/fonts/line limits as a full caption, for the rail slot only.
  private var captionReserve: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("\n\n")
        .font(Self.titleFont)
        .lineLimit(Self.titleLineLimit)
      Text("EPISODE 99")
        .font(Self.numberFont)
        .textCase(.uppercase)
        .lineLimit(1)
    }
    .frame(width: Self.cardWidth - Self.captionPadding * 2, alignment: .leading)
  }

  @ViewBuilder
  private var caption: some View {
    VStack(alignment: .leading, spacing: 6) {
      if !episodeTitle.isEmpty {
        Text(episodeTitle)
          .font(Self.titleFont)
          .foregroundStyle(Color.KinoPub.text)
          .lineLimit(Self.titleLineLimit)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)

        Text(episodeNumberLabel)
          .font(Self.numberFont)
          .foregroundStyle(Color.secondary)
          .textCase(.uppercase)
          .lineLimit(1)
      } else {
        Text(episodeNumberLabel)
          .font(Self.titleFont)
          .foregroundStyle(Color.KinoPub.text)
          .lineLimit(1)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(width: Self.cardWidth - Self.captionPadding * 2, alignment: .leading)
  }

  private var still: some View {
    AsyncImage(url: URL(string: episode.thumbnail),
               transaction: Transaction(animation: .easeIn(duration: 0.25))) { phase in
      ZStack(alignment: .bottom) {
        Group {
          if let image = phase.image {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .transition(.opacity)
          } else {
            Color.KinoPub.placeholder
          }
        }
        .frame(width: Self.cardWidth, height: Self.stillHeight)
        .clipped()
              .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))


        if let progress {
          progressBar(progress)
        }
      }
    }
    .frame(width: Self.cardWidth, height: Self.stillHeight)
//    .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
  }

  private func progressBar(_ progress: Double) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
          Capsule().fill(Color.gray.opacity(0.5))
        Capsule()
          .fill(Color.KinoPub.accent)
          .frame(width: geometry.size.width * progress)
          .shadow(radius: 8)
      }
    }
    .frame(height: 10)
    .padding(.horizontal, 0)
    .padding(.bottom, 0)
  }

  static let titleLineLimit = 3

#if os(tvOS)
  static let cardWidth: CGFloat = 480
  static let stillHeight: CGFloat = 270
  static let cornerRadius: CGFloat = 18
  static let plateRadius: CGFloat = 18
  static let captionSpacing: CGFloat = 12
  static let captionPadding: CGFloat = 20
  static let numberFont: Font = .system(size: 20, weight: .bold)
  static let titleFont: Font = .system(size: 28, weight: .semibold)
#else
  static let cardWidth: CGFloat = 300
  static let stillHeight: CGFloat = 169
  static let cornerRadius: CGFloat = 12
  static let plateRadius: CGFloat = 14
  static let captionSpacing: CGFloat = 8
  static let captionPadding: CGFloat = 8
  static let numberFont: Font = .system(size: 11, weight: .semibold)
  static let titleFont: Font = .system(size: 15, weight: .medium)
#endif
}

/// Press feedback only — focus plate and scale live on `EpisodeRailCard`.
private struct EpisodeCardButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.92 : 1.0)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
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
            .foregroundStyle(
                isSelected || isFocused ? Color.primary : Color.secondary
            )
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isFocused ? Color.secondary.opacity(0.4) : Color.clear)
          )
    
//        .scaleEffect(isFocused ? 1.06 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
  }
}
