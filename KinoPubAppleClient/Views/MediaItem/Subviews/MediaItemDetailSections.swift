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
    let value: Double
    let votes: Int?
  }

  /// IMDb and Kinopoisk lead. kino.pub's own tally goes last: it is a thumbs
  /// up/down from a handful of users, not a score worth ranking above the others.
  private var scores: [Score] {
    var result: [Score] = []
    if let imdb = mediaItem.imdbRating, imdb > 0 {
      result.append(Score(id: "IMDb", value: imdb, votes: mediaItem.imdbVotes))
    }
    if let kp = mediaItem.kinopoiskRating, kp > 0 {
      result.append(Score(id: "Kinopoisk", value: kp, votes: mediaItem.kinopoiskVotes))
    }
    return result
  }

  var body: some View {
    if !scores.isEmpty || mediaItem.communityVotes != nil {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("Ratings")

        HStack(alignment: .top, spacing: Self.spacing) {
          ForEach(scores) { score in
            tile(score)
          }
          if let votes = mediaItem.communityVotes {
            communityTile(likes: votes.likes, dislikes: votes.dislikes)
          }
        }
        .padding(.horizontal, MediaItemLayout.horizontalInset)
      }
    }
  }

  /// Shown as the tally it actually is, rather than dressed up as a score.
  private func communityTile(likes: Int, dislikes: Int) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 16) {
        Label("\(likes)", systemImage: "hand.thumbsup.fill")
        Label("\(dislikes)", systemImage: "hand.thumbsdown.fill")
      }
      .font(Self.votesFont)
      .foregroundStyle(Color.KinoPub.text)

      Text("Kinopub")
        .font(Self.captionFont)
        .foregroundStyle(Color.KinoPub.subtitle)
    }
    .frame(width: Self.tileWidth, alignment: .leading)
    .padding(Self.tilePadding)
    .background(Color.KinoPub.selectionBackground.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func tile(_ score: Score) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(String(format: "%.1f / 10", score.value))
        .font(Self.valueFont)
        .foregroundStyle(Color.KinoPub.text)

      Text(score.id)
        .font(Self.captionFont)
        .foregroundStyle(Color.KinoPub.subtitle)

      stars(for: score.value)

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

  /// Five stars over a ten-point score, halves included.
  private func stars(for value: Double) -> some View {
    let filled = value / 2
    return HStack(spacing: 4) {
      ForEach(0..<5, id: \.self) { index in
        let position = Double(index)
        Image(systemName: filled >= position + 1 ? "star.fill"
              : (filled >= position + 0.5 ? "star.leadinghalf.filled" : "star"))
          .font(.system(size: Self.starSize))
          .foregroundStyle(Color.KinoPub.text.opacity(filled >= position + 0.5 ? 1 : 0.35))
      }
    }
  }

#if os(tvOS)
  static let spacing: CGFloat = 24
  static let tileWidth: CGFloat = 260
  static let tilePadding: CGFloat = 24
  static let valueFont: Font = .system(size: 40, weight: .semibold)
  static let captionFont: Font = .system(size: 22, weight: .regular)
  static let starSize: CGFloat = 22
  static let votesFont: Font = .system(size: 28, weight: .semibold)
#else
  static let spacing: CGFloat = 12
  static let tileWidth: CGFloat = 150
  static let tilePadding: CGFloat = 14
  static let valueFont: Font = .system(size: 24, weight: .semibold)
  static let captionFont: Font = .system(size: 13, weight: .regular)
  static let starSize: CGFloat = 12
  static let votesFont: Font = .system(size: 17, weight: .semibold)
#endif
}

// MARK: - Cast

/// Round portraits, as on Apple TV. kino.pub sends only names — no photos and no
/// character names — so these are initials rather than faces.
struct MediaItemCastSection: View {

  let mediaItem: MediaItem

  private var members: [(role: String, names: [String])] {
    var result: [(String, [String])] = []
    if !mediaItem.directorNames.isEmpty {
      result.append(("Director", mediaItem.directorNames))
    }
    if !mediaItem.castMembers.isEmpty {
      result.append(("Cast", mediaItem.castMembers))
    }
    return result
  }

  private var people: [(name: String, role: String)] {
    members.flatMap { group in group.names.map { ($0, group.role) } }
  }

  var body: some View {
    if !people.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        MediaItemSectionHeader("Cast and crew")

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: Self.spacing) {
            ForEach(Array(people.enumerated()), id: \.offset) { _, person in
              portrait(name: person.name, role: person.role)
            }
          }
          .padding(.horizontal, MediaItemLayout.horizontalInset)
          .padding(.vertical, 4)
        }
      }
    }
  }

  private func portrait(name: String, role: String) -> some View {
    VStack(spacing: 8) {
      Circle()
        .fill(Color.KinoPub.selectionBackground)
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .overlay {
          Text(initials(of: name))
            .font(Self.initialsFont)
            .foregroundStyle(Color.KinoPub.text)
        }

      Text(name)
        .font(Self.nameFont)
        .foregroundStyle(Color.KinoPub.text)
        .lineLimit(1)

      Text(LocalizedStringKey(role))
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
  static let initialsFont: Font = .system(size: 44, weight: .medium)
  static let nameFont: Font = .system(size: 24, weight: .medium)
  static let roleFont: Font = .system(size: 20, weight: .regular)
#else
  static let spacing: CGFloat = 16
  static let avatarSize: CGFloat = 72
  static let initialsFont: Font = .system(size: 24, weight: .medium)
  static let nameFont: Font = .system(size: 14, weight: .medium)
  static let roleFont: Font = .system(size: 12, weight: .regular)
#endif
}

// MARK: - Information columns

/// Information · Translation · Audio, side by side where there is room and stacked
/// where there isn't — the shape Apple uses for Information · Languages · Accessibility.
struct MediaItemInfoColumns: View {

  let mediaItem: MediaItem

  private static let maxSubtitleLanguages = 6

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

  private var translationRows: [(String, String)] {
    var rows: [(String, String)] = []
    if let voice = mediaItem.voice, !voice.isEmpty {
      rows.append(("MediaItem_Voice", voice))
    }
    let subtitles = mediaItem.subtitleLanguages
    if !subtitles.isEmpty {
      // Some items carry 20+ subtitle languages; the full list swamps the column.
      let shown = subtitles.prefix(Self.maxSubtitleLanguages).joined(separator: ", ")
      let remainder = subtitles.count - Self.maxSubtitleLanguages
      rows.append(("Subtitles", remainder > 0 ? "\(shown) +\(remainder)" : shown))
    }
    return rows
  }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: Self.columnSpacing) {
        columns
      }
      VStack(alignment: .leading, spacing: Self.columnSpacing) {
        columns
      }
    }
    .padding(.horizontal, MediaItemLayout.horizontalInset)
  }

  @ViewBuilder
  private var columns: some View {
    column(title: "Information", rows: informationRows)

    if !translationRows.isEmpty {
      column(title: "Translation", rows: translationRows)
    }

    if !mediaItem.audioTrackDescriptions.isEmpty {
      audioColumn
    }
  }

  private func column(title: LocalizedStringKey, rows: [(String, String)]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(Self.headerFont)
        .foregroundStyle(Color.KinoPub.text)

      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        HStack(alignment: .top, spacing: 12) {
          Text(LocalizedStringKey(row.0))
            .font(Self.keyFont)
            .foregroundStyle(Color.KinoPub.subtitle)
            .frame(width: Self.keyWidth, alignment: .leading)
          Text(row.1)
            .font(Self.valueFont)
            .foregroundStyle(Color.KinoPub.text)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .frame(width: Self.columnWidth, alignment: .leading)
  }

  private var audioColumn: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Audio")
        .font(Self.headerFont)
        .foregroundStyle(Color.KinoPub.text)

      ForEach(Array(mediaItem.audioTrackDescriptions.enumerated()), id: \.offset) { index, track in
        Text("\(index + 1). \(track)")
          .font(Self.valueFont)
          .foregroundStyle(Color.KinoPub.text)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(width: Self.columnWidth, alignment: .leading)
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
  static let headerFont: Font = .system(size: 30, weight: .semibold)
  static let keyFont: Font = .system(size: 22, weight: .regular)
  static let valueFont: Font = .system(size: 22, weight: .regular)
#else
  static let columnSpacing: CGFloat = 28
  static let columnWidth: CGFloat = 260
  static let keyWidth: CGFloat = 90
  static let headerFont: Font = .system(size: 18, weight: .semibold)
  static let keyFont: Font = .system(size: 13, weight: .regular)
  static let valueFont: Font = .system(size: 13, weight: .regular)
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
