//
//  MediaItemDetailSections.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

// MARK: - Ratings

/// Score tiles with their vote counts, the way microiptv lays them out: one per
/// source, hidden when that source has nothing.
struct MediaItemRatingsSection: View {

  let mediaItem: MediaItem

  private struct Score: Identifiable {
    let id: String
    let logo: MediaScoreLogo.Source
    let value: Double
    let votes: Int?
  }

  private var scores: [Score] {
    var result: [Score] = []
    if let imdb = mediaItem.imdbRating, imdb > 0 {
      result.append(Score(id: "IMDb", logo: .imdb, value: imdb, votes: mediaItem.imdbVotes))
    }
    if let kp = mediaItem.kinopoiskRating, kp > 0 {
      result.append(Score(id: "Kinopoisk", logo: .kinopoisk, value: kp, votes: mediaItem.kinopoiskVotes))
    }
    return result
  }

  var body: some View {
    if !scores.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("Ratings")

        HStack(alignment: .top, spacing: Self.spacing) {
          ForEach(scores) { score in
            tile(score)
          }
          // kino.pub's own thumbs up/down tally, parked until we know what it
          // actually counts — it comes back empty on everything we have looked at.
          //          if let votes = mediaItem.communityVotes {
          //            communityTile(likes: votes.likes, dislikes: votes.dislikes)
          //          }
        }
        .padding(.horizontal, MediaItemLayout.horizontalInset)
      }
    }
  }

  //  /// Shown as the tally it actually is, rather than dressed up as a score.
  //  private func communityTile(likes: Int, dislikes: Int) -> some View {
  //    VStack(alignment: .leading, spacing: 8) {
  //      HStack(spacing: 16) {
  //        Label("\(likes)", systemImage: "hand.thumbsup.fill")
  //        Label("\(dislikes)", systemImage: "hand.thumbsdown.fill")
  //      }
  //      .font(Self.votesFont)
  //      .foregroundStyle(Color.KinoPub.text)
  //
  //      Text("Kinopub")
  //        .font(Self.captionFont)
  //        .foregroundStyle(Color.KinoPub.subtitle)
  //    }
  //    .frame(width: Self.tileWidth, alignment: .leading)
  //    .padding(Self.tilePadding)
  //    .background(Color.KinoPub.selectionBackground.opacity(0.5),
  //                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  //  }

  /// A rating is not an action, but on tvOS a row of inert tiles is a row the remote
  /// skips over entirely — the focus engine only scrolls to what it can focus. So each
  /// tile is a control: it lifts under focus like the cast portraits do, selecting it
  /// does nothing, and the D-pad always moves back out of it. The button carries no
  /// visible chrome of its own; the tile already looks like the panel it is.
  private func tile(_ score: Score) -> some View {
    Button {
      // Nothing to open — a score is a fact, not a destination. The tile earns its
      // focus stop by making the row reachable, not by doing something when pressed.
    } label: {
      tileContent(score)
    }
    .buttonStyle(RatingTileButtonStyle())
  }

  /// The number carries the tile, so it is left to stand on its own: no "/ 10"
  /// spelling out a scale everyone knows, and no star row restating it in pictures.
  private func tileContent(_ score: Score) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(String(format: "%.1f", score.value))
        .font(Self.valueFont)
        .foregroundStyle(Color.KinoPub.text)

      HStack(spacing: 8) {
        MediaScoreLogo(score.logo, height: Self.logoHeight(score.logo))
        Text(score.id)
          .font(Self.captionFont)
      }
      .foregroundStyle(Color.KinoPub.subtitle)

      if let votes = score.votes, votes > 0 {
        Text("\(votes.formatted(.number.grouping(.automatic))) \("votes".localized)")
          .font(Self.captionFont)
          .foregroundStyle(Color.KinoPub.subtitle)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(width: Self.tileWidth, alignment: .leading)
    .padding(Self.tilePadding)
    .background(Color.KinoPub.selectionBackground.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  /// The two marks are drawn to different proportions: matched by height they read
  /// as one bigger than the other, so Kinopoisk's gets a little more room.
  private static func logoHeight(_ source: MediaScoreLogo.Source) -> CGFloat {
    switch source {
    case .imdb: return imdbLogoHeight
    case .kinopoisk: return kinopoiskLogoHeight
    }
  }

#if os(tvOS)
  static let spacing: CGFloat = 24
  static let tileWidth: CGFloat = 260
  static let tilePadding: CGFloat = 24
  static let valueFont: Font = .system(size: 40, weight: .semibold)
  static let captionFont: Font = .system(size: 22, weight: .regular)
  static let imdbLogoHeight: CGFloat = 22
  static let kinopoiskLogoHeight: CGFloat = 24
#else
  static let spacing: CGFloat = 12
  static let tileWidth: CGFloat = 150
  static let tilePadding: CGFloat = 14
  static let valueFont: Font = .system(size: 24, weight: .semibold)
  static let captionFont: Font = .system(size: 13, weight: .regular)
  static let imdbLogoHeight: CGFloat = 13
  static let kinopoiskLogoHeight: CGFloat = 14
#endif
}

/// The lift a score tile takes under focus, matched to the cast portraits: a small
/// scale and a shadow, no filled highlight — the tile is already a solid panel, so a
/// backed focus state would double up on it. Same shape as `PortraitButtonStyle`.
private struct RatingTileButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Tile(configuration: configuration)
  }

  private struct Tile: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
        .scaleEffect(isFocused ? 1.05 : (configuration.isPressed ? 0.98 : 1.0))
        .shadow(color: .black.opacity(isFocused ? 0.45 : 0), radius: 14, y: 6)
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }
  }
}

// MARK: - Cast

/// Round portraits, as on Apple TV. kino.pub sends only names — no photos and no
/// character names — so these are initials rather than faces.
///
/// Each one leads to that person's credits, which is also what makes the rail
/// reachable: a tvOS scroll view moves by focus, and portraits that were plain text
/// left everyone past the right edge of the screen unreachable.
struct MediaItemCastSection: View {

  let mediaItem: MediaItem
  let linkProvider: NavigationLinkProvider

  private var people: [MediaPerson] {
    mediaItem.directorNames.map { MediaPerson(name: $0, role: .director) }
      + mediaItem.castMembers.map { MediaPerson(name: $0, role: .actor) }
  }

  var body: some View {
    if !people.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("Cast and crew")

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: Self.spacing) {
            ForEach(people) { person in
              NavigationLink(value: linkProvider.person(for: person)) {
                portrait(person)
              }
              .buttonStyle(PortraitButtonStyle())
            }
          }
          .padding(.horizontal, MediaItemLayout.horizontalInset)
          .padding(.vertical, Self.focusPadding)
        }
      }
    }
  }

  private func portrait(_ person: MediaPerson) -> some View {
    VStack(spacing: 8) {
      Circle()
        .fill(Color.KinoPub.selectionBackground)
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .overlay {
          Text(initials(of: person.name))
            .font(Self.initialsFont)
            .foregroundStyle(Color.KinoPub.text)
        }

      Text(person.name)
        .font(Self.nameFont)
        .foregroundStyle(Color.KinoPub.text)
        .lineLimit(1)

      Text(LocalizedStringKey(person.role.titleKey))
        .font(Self.roleFont)
        .foregroundStyle(Color.KinoPub.subtitle)
        .lineLimit(1)
    }
    .frame(width: Self.avatarSize + 24)
  }

  private func initials(of name: String) -> String {
    name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
  }

#if os(tvOS)
  static let spacing: CGFloat = 28
  static let avatarSize: CGFloat = 140
  static let focusPadding: CGFloat = 16
  static let initialsFont: Font = .system(size: 44, weight: .medium)
  static let nameFont: Font = .system(size: 24, weight: .medium)
  static let roleFont: Font = .system(size: 20, weight: .regular)
#else
  static let spacing: CGFloat = 16
  static let avatarSize: CGFloat = 72
  static let focusPadding: CGFloat = 4
  static let initialsFont: Font = .system(size: 24, weight: .medium)
  static let nameFont: Font = .system(size: 14, weight: .medium)
  static let roleFont: Font = .system(size: 12, weight: .regular)
#endif
}

/// The lift the episode cards use, kept a touch smaller: these are round and sit in a
/// denser rail, where the same jump reads as a wobble.
private struct PortraitButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Portrait(configuration: configuration)
  }

  private struct Portrait: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
        .scaleEffect(isFocused ? 1.05 : (configuration.isPressed ? 0.98 : 1.0))
        .shadow(color: .black.opacity(isFocused ? 0.45 : 0), radius: 14, y: 6)
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }
  }
}

// MARK: - Similar

/// "More like this": the related items kino.pub returns for this one, drawn with the
/// same poster cards as every catalog row so the page ends the way a browse screen
/// does. Each card leads to that item's own page, which is also what makes the rail
/// reachable on tvOS — a scroll view moves by focus, so plain artwork past the right
/// edge would strand the user. The whole section is absent until there is something
/// to show.
struct MediaItemSimilarSection: View {

  let items: [MediaItem]
  let linkProvider: NavigationLinkProvider

  var body: some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("More like this")

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: Self.spacing) {
            ForEach(items, id: \.id) { item in
              NavigationLink(value: linkProvider.link(for: item)) {
                MediaCardView(card: MediaCard(item), caption: .always)
              }
#if os(tvOS)
              // Same native parallax focus effect as the catalog rows.
              .buttonStyle(.borderless)
#else
              .buttonStyle(SimilarCardButtonStyle())
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
  static let spacing: CGFloat = 36
  static let focusPadding: CGFloat = 32
#else
  static let spacing: CGFloat = 16
  static let focusPadding: CGFloat = 6
#endif
}

/// The poster lift the catalog rows use, kept here so the related rail reads the same
/// as every other row on the page. Mirrors `MediaCardButtonStyle` in KinoPubUI, which
/// is internal to that package.
private struct SimilarCardButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Card(configuration: configuration)
  }

  private struct Card: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
        .environment(\.cardFocused, isFocused)
        .scaleEffect(isFocused ? 1.08 : (configuration.isPressed ? 0.97 : 1.0))
        .shadow(color: .black.opacity(isFocused ? 0.45 : 0), radius: 18, y: 10)
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }
  }
}

// MARK: - Information columns

/// Information · Translation · Audio, side by side where there is room and stacked
/// where there isn't — the shape Apple uses for Information · Languages · Accessibility.
///
/// Each column is a control rather than a block of text. tvOS scrolls by moving
/// focus, so a page whose bottom half holds nothing focusable cannot be scrolled to
/// at all — these columns were unreachable. Selecting one opens it in full, which is
/// also where the lists clipped down here (the subtitle languages above all) are
/// shown whole.
struct MediaItemInfoColumns: View {

  let mediaItem: MediaItem

  private static let maxSubtitleLanguages = 6

  private struct Row: Identifiable {
    let id: Int
    /// Nil for the audio tracks, which are a plain list rather than a table.
    let key: String?
    let value: String
  }

  private struct Column: Identifiable {
    let id: String
    let rows: [Row]
    /// What the column shows once opened: the same rows without the clamping.
    let fullRows: [Row]
  }

  private var informationRows: [(String, String)] {
    var rows: [(String, String)] = []
    if !mediaItem.genreNames.isEmpty {
      rows.append(("MediaItem_Genre", mediaItem.genreNames.joined(separator: ", ")))
    }
    if !mediaItem.countryNames.isEmpty {
      rows.append(("MediaItem_Country", mediaItem.countryNames.joined(separator: ", ")))
    }
    if mediaItem.year > 0 {
      rows.append(("MediaItem_Year", "\(mediaItem.year)"))
    }
    let duration = mediaItem.displayDuration
    if !duration.isEmpty {
      rows.append(("MediaItem_Duration", duration))
    }
    if let total = mediaItem.totalDurationDisplay {
      rows.append(("Total duration", total))
    }
    rows.append(("Added", Self.date(mediaItem.createdAt)))
    rows.append(("Updated", Self.date(mediaItem.updatedAt)))
    return rows
  }

  /// Some items carry 20+ subtitle languages; the full list swamps the column, so it
  /// is clamped here and left whole for the opened version.
  private func translationRows(clamped: Bool) -> [(String, String)] {
    var rows: [(String, String)] = []
    if let voice = mediaItem.voice, !voice.isEmpty {
      rows.append(("MediaItem_Voice", voice))
    }
    let subtitles = mediaItem.subtitleLanguages
    if !subtitles.isEmpty {
      let remainder = subtitles.count - Self.maxSubtitleLanguages
      if clamped, remainder > 0 {
        let shown = subtitles.prefix(Self.maxSubtitleLanguages).joined(separator: ", ")
        rows.append(("Subtitles", "\(shown) +\(remainder)"))
      } else {
        rows.append(("Subtitles", subtitles.joined(separator: ", ")))
      }
    }
    return rows
  }

  private var audioRows: [Row] {
    mediaItem.audioTrackDescriptions.enumerated().map { index, track in
      Row(id: index, key: nil, value: track)
    }
  }

  private var columns: [Column] {
    let information = Self.rows(informationRows)
    var result = [Column(id: "Information", rows: information, fullRows: information)]

    let translation = translationRows(clamped: true)
    if !translation.isEmpty {
      result.append(Column(id: "Translation",
                           rows: Self.rows(translation),
                           fullRows: Self.rows(translationRows(clamped: false))))
    }

    if !mediaItem.audioTrackDescriptions.isEmpty {
      result.append(Column(id: "Audio", rows: audioRows, fullRows: audioRows))
    }
    return result
  }

  private static func rows(_ pairs: [(String, String)]) -> [Row] {
    pairs.enumerated().map { Row(id: $0.offset, key: $0.element.0, value: $0.element.1) }
  }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: Self.columnSpacing) {
        columnViews
      }
      VStack(alignment: .leading, spacing: Self.columnSpacing) {
        columnViews
      }
    }
    .padding(.horizontal, MediaItemLayout.horizontalInset)
  }

  private var columnViews: some View {
    ForEach(columns) { ColumnView(column: $0) }
  }

  private struct ColumnView: View {

    let column: Column

    @State private var showsFullText = false

    var body: some View {
      Button {
        showsFullText = true
      } label: {
        VStack(alignment: .leading, spacing: 12) {
          Text(LocalizedStringKey(column.id))
            .font(MediaItemInfoColumns.headerFont)
            .foregroundStyle(Color.KinoPub.text)

          ForEach(column.rows) { row in
            MediaItemInfoColumns.rowView(row, keyWidth: MediaItemInfoColumns.keyWidth)
          }
          .font(MediaItemInfoColumns.rowFont)
        }
        .frame(width: MediaItemInfoColumns.columnWidth, alignment: .leading)
      }
      .buttonStyle(ExpandableButtonStyle())
      .sheet(isPresented: $showsFullText) {
        MediaItemDetailSheet(title: Text(LocalizedStringKey(column.id))) {
          VStack(alignment: .leading, spacing: 12) {
            ForEach(column.fullRows) { row in
              MediaItemInfoColumns.rowView(row, keyWidth: MediaItemInfoColumns.sheetKeyWidth)
            }
          }
          .font(MediaItemSheetLayout.bodyFont)
        }
      }
    }
  }

  /// Fonts come from whichever context the row is dropped into — the column and the
  /// opened sheet set the same face at two sizes. Key and value only differ in colour.
  private static func rowView(_ row: Row, keyWidth: CGFloat) -> some View {
    HStack(alignment: .top, spacing: 12) {
      if let key = row.key {
        Text(LocalizedStringKey(key))
          .foregroundStyle(Color.KinoPub.subtitle)
          .frame(width: keyWidth, alignment: .leading)
      }
      Text(row.value)
        .foregroundStyle(Color.KinoPub.text)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private static func date(_ timestamp: Int) -> String {
    guard timestamp > 0 else { return "—" }
    return Date(timeIntervalSince1970: TimeInterval(timestamp))
      .formatted(date: .abbreviated, time: .omitted)
  }

#if os(tvOS)
  static let columnSpacing: CGFloat = 60
  static let columnWidth: CGFloat = 480
  static let keyWidth: CGFloat = 150
  static let sheetKeyWidth: CGFloat = 220
  static let headerFont: Font = .system(size: 30, weight: .semibold)
  static let rowFont: Font = .system(size: 22, weight: .regular)
#else
  static let columnSpacing: CGFloat = 28
  static let columnWidth: CGFloat = 260
  static let keyWidth: CGFloat = 90
  static let sheetKeyWidth: CGFloat = 120
  static let headerFont: Font = .system(size: 18, weight: .semibold)
  static let rowFont: Font = .system(size: 13, weight: .regular)
#endif
}

// MARK: - Shared bits

struct MediaItemSectionHeader: View {
  private let title: LocalizedStringKey

  init(_ title: LocalizedStringKey) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .font(MediaItemLayout.headerFont)
      .foregroundStyle(Color.KinoPub.text)
      .padding(.horizontal, MediaItemLayout.horizontalInset)
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
/// it opens the full text, rather than expanding in place and pushing the artwork
/// around.
struct MediaItemPlotView: View {

  let title: String
  let plot: String
  /// Shared with the other hero controls so focusing "More" does not count as
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

  /// A focusable, openable control only when there is more to read. When the whole plot
  /// fits it is plain text: no "More", and — the part that matters on tvOS — not a
  /// button, so it does not sit in the page as a focus stop that opens a sheet showing
  /// exactly what is already on screen.
  @ViewBuilder
  private var content: some View {
    if isTruncated {
      Button {
        showsFullText = true
      } label: {
        paragraph(showsMore: true)
      }
      .buttonStyle(ExpandableButtonStyle())
      .focused($focus, equals: .heroOther)
      .sheet(isPresented: $showsFullText) {
        MediaItemDetailSheet(title: Text(title)) {
          Text(plot)
            .font(MediaItemSheetLayout.bodyFont)
            .foregroundStyle(Color.KinoPub.text)
            .multilineTextAlignment(.leading)
        }
      }
    } else {
      paragraph(showsMore: false)
    }
  }

  private func paragraph(showsMore: Bool) -> some View {
    HStack(alignment: .lastTextBaseline, spacing: 14) {
      Text(plot)
        .font(Self.font)
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
      // narrows a paragraph that has room to spare.
      if showsMore {
        Text("More")
          .font(Self.moreFont.weight(.semibold))
          .textCase(.uppercase)
          .tracking(Self.moreTracking)
          .opacity(Self.moreOpacity)
          .fixedSize()
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
  static let lineLimit = 3
  static let maxWidth: CGFloat = 900
  static let moreTracking: CGFloat = 1.2
#else
  static let lineLimit = 3
  static let maxWidth: CGFloat = 560
  static let moreTracking: CGFloat = 0.8
#endif
}

/// Anything on this page that can be opened in full: the synopsis and the info
/// columns. Secondary at rest so it sits behind the title and buttons, solid and
/// backed once focused so it reads as the control it is. Text that sets its own
/// colour — the columns do — keeps it and picks up only the highlight.
private struct ExpandableButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    // Not named `Body`: that collides with `ButtonStyle.Body`.
    ExpandableLabel(configuration: configuration)
  }

  private struct ExpandableLabel: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
        // At rest this is a step down from the title, not the full 40% fade of the
        // subtitle colour: the synopsis sits over artwork now, and at 0.6 it went
        // soft against a bright frame.
        .foregroundStyle(isFocused ? Color.KinoPub.text : Color.KinoPub.text.opacity(0.8))
        // Inset whether or not it is focused and then pulled back out again: making
        // the padding appear on focus kept the frame the same width and re-wrapped
        // the paragraph inside it. The highlight bleeds into the surrounding gaps
        // instead, which is what it does on tvOS anyway.
        .padding(.horizontal, Self.horizontalInset)
        .padding(.vertical, Self.verticalInset)
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.KinoPub.selectionBackground.opacity(isFocused ? 0.85 : 0))
        )
        .padding(.horizontal, -Self.horizontalInset)
        .padding(.vertical, -Self.verticalInset)
        .animation(.easeOut(duration: 0.15), value: isFocused)
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
  static let maxWidth: CGFloat = 1200
  static let padding: CGFloat = 80
#else
  static let titleFont: Font = .system(size: 26, weight: .bold)
  static let bodyFont: Font = .system(size: 16, weight: .regular)
  static let maxWidth: CGFloat = 640
  static let padding: CGFloat = 24
#endif
}
