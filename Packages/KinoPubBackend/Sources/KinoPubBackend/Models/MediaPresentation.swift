//
//  MediaPresentation.swift
//
//

import Foundation

/// What kind of thing a title is, as far as *presentation* is concerned — not the same
/// question as `MediaType`, which is the API's filing cabinet.
///
/// The axis that matters is **whether faces carry the title**. A film is sold on the
/// people in it, so their portraits are a section of their own. A concert, a stand-up
/// set, a documentary or an anime is not: its "cast" is a list of names, and a rail of
/// monogram circles for people nobody is looking for is a shelf of noise.
public enum MediaPresentationKind: String, Sendable, CaseIterable {
  /// Characters, played by actors. The default, and the only kind that gets faces.
  case fiction
  /// Real people, as themselves — `documovie` / `docuserial`, or the documentary genre
  /// on any type.
  case documentary
  /// A stage, not a story: concerts and stand-up (genre 101).
  case performance
  /// The credited people are not the faces on screen. Voice actors may earn portraits
  /// once we carry them as such; kino.pub's flat `cast` string is not that.
  case anime
}

/// **One profile decides how a title's type and genre change the way it is presented.**
/// Views ask the profile; they never test `type == "concert"` themselves. A per-view
/// type check is how a rule ends up applied on the detail page and forgotten on the
/// poster, and how the same word gets two labels on two surfaces.
///
/// Surfaces this is meant to cover, and where each stands:
///
/// | Surface | Decided |
/// | --- | --- |
/// | Detail sections — which appear at all | `showsCastPortraits` (people rail) |
/// | Labels — what a section or field is called | `creditsTitleKey` |
/// | Hero — the written fields under the synopsis | `showsHeroCastLine` |
/// | Poster (vertical) | nothing yet — add here when it is decided, not in the cell |
/// | Playable object (horizontal) | nothing yet — same rule |
///
/// Add a case or a property here when a new rule arrives; do not grow a second one of
/// these next to a view.
public struct MediaPresentationProfile: Equatable, Sendable {

  public let kind: MediaPresentationKind

  public init(kind: MediaPresentationKind) {
    self.kind = kind
  }

  /// The people rail — poster-shaped portraits on iOS/macOS, TVUIKit monogram circles
  /// on tvOS. Fiction only; everywhere else the same names are a row in the
  /// information table, next to qualities and languages.
  public var showsCastPortraits: Bool { kind == .fiction }

  /// What the people are called where they are listed. "Cast & Crew" over a rail of
  /// faces; "Credits" over a list of names, because a concert has no cast.
  public var creditsTitleKey: String {
    showsCastPortraits ? "Cast & Crew" : "MediaItem_Credits"
  }

  /// The hero's "Starring …" line, under the synopsis. Off wherever there is no
  /// starring to speak of — nobody stars in a stand-up set.
  public var showsHeroCastLine: Bool { kind == .fiction }
}

// MARK: - Reading the kind off an item

public extension MediaPresentationProfile {

  /// Type first, then genre: a `documovie` is a documentary whatever its genres say,
  /// while a documentary or a stand-up set filed as a plain `movie` is only knowable
  /// from the genre list.
  ///
  /// Genre 101 is stand-up — the one id kino.pub has confirmed to us. The rest match on
  /// the genre's own title, in both languages the API answers in, because we hold no id
  /// table for them (`filter.genres` in `kpapp.link/config.json` is where one would
  /// come from — see docs/providers/kinopub/references.md).
  init(type: String, genres: [TypeClass]) {
    self.init(kind: Self.kind(type: type, genres: genres))
  }

  private static func kind(type: String, genres: [TypeClass]) -> MediaPresentationKind {
    switch type.lowercased() {
    case "documovie", "docuserial": return .documentary
    case "concert": return .performance
    default: break
    }

    let ids = Set(genres.map(\.id))
    if !ids.isDisjoint(with: standupGenreIDs) { return .performance }

    let titles = genres.compactMap(\.title).map(normalized)
    if titles.contains(where: { matches($0, animeGenreWords) }) { return .anime }
    if titles.contains(where: { matches($0, documentaryGenreWords) }) { return .documentary }
    if titles.contains(where: { matches($0, standupGenreWords) }) { return .performance }

    return .fiction
  }

  private static func normalized(_ title: String) -> String {
    title.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                  locale: nil)
  }

  private static func matches(_ title: String, _ words: [String]) -> Bool {
    words.contains { title.contains($0) }
  }

  /// Confirmed by the user against `/v1/items?genre=101`.
  private static let standupGenreIDs: Set<Int> = [101]
  private static let standupGenreWords = ["стендап", "стенд-ап", "stand-up", "standup"]
  private static let animeGenreWords = ["аниме", "anime"]
  private static let documentaryGenreWords = ["документальн", "documentar"]
}

public extension MediaItem {
  /// How this title should be presented. Ask this, never `type` directly.
  var presentation: MediaPresentationProfile {
    MediaPresentationProfile(type: type, genres: genres)
  }
}
