//
//  MediaPresentation.swift
//
//

import Foundation

/// What kind of thing a title is, as far as *presentation* is concerned — not the same
/// question as `MediaType`, which is the API's filing cabinet.
///
/// The axis that matters is **whether faces carry the title**. A film is sold on the
/// actors in it, so their portraits are a section of their own. A concert, a stand-up
/// set, a documentary, a TV show or anything animated is not: its people are a list of
/// names, and a rail of monogram circles for faces nobody would recognize is a shelf of
/// noise.
public enum MediaPresentationKind: String, Sendable, CaseIterable {
  /// Characters, played by actors whose faces are the point. The default, and the only
  /// kind that gets a rail of portraits.
  case fiction
  /// Real people, as themselves — `documovie` / `docuserial`, or the documentary genre
  /// on any type.
  case documentary
  /// A stage and a setlist. Its people are asked for their other concerts.
  case concert
  /// A stage and a microphone — **genre 101**. Its people are asked for everything
  /// else they did, where a film or a series is the more interesting answer.
  case standup
  /// Drawn: anime, cartoons and cartoon series (genre 23). The credited people are not
  /// the faces on screen. Voice actors may earn portraits once we carry them as such;
  /// kino.pub's flat `cast` string is not that.
  case animation
  /// `tvshow` — hosts and guests, episodes that are broadcasts.
  case show
}

/// What to call whoever is credited as having made this. A film has a director; a
/// series, a show or a documentary has creators, and kino.pub files them in the same
/// `director` field.
public enum MediaAuthorRole: String, Sendable {
  case director
  case creator
}

/// **One profile decides how a title's type and genre change the way it is presented.**
/// Views ask the profile; they never test `type == "concert"` themselves. A per-view
/// type check is how a rule ends up applied on the detail page and forgotten on the
/// poster, and how the same word gets two labels on two surfaces.
///
/// Surfaces it answers for today: detail sections (`showsCastPortraits`,
/// `showsAuthorShelf`), labels (`castSectionTitleKey`, `authorCaptionKey`,
/// `authorShelfTitleKey(count:)`) and the hero's written fields (`showsHeroCastLine`).
/// The poster and the horizontal card have no kind-specific rule yet — when one is
/// decided it becomes a property here, never an `if` in the cell.
///
/// **The rules themselves are product, and are written down as such:**
/// `docs/product/media-presentation.md`. This type implements them; it is not where
/// they are decided.
public struct MediaPresentationProfile: Equatable, Sendable {

  public let kind: MediaPresentationKind
  public let authorRole: MediaAuthorRole
  /// Anime specifically, not animation in general.
  ///
  /// It changes **nothing** about presentation — an anime and a cartoon are drawn the
  /// same way — so it is not a `kind`. It changes which audio and subtitles a title
  /// opens with, because anime is the case where watching the original with subtitles is
  /// a normal preference and a Russian cartoon is not. One flag, here, so no surface has
  /// to re-derive it from a genre string: `docs/product/playback-tracks.md`.
  public let isAnime: Bool

  public init(kind: MediaPresentationKind,
              authorRole: MediaAuthorRole = .director,
              isAnime: Bool = false) {
    self.kind = kind
    self.authorRole = authorRole
    self.isAnime = isAnime
  }

  /// The people rail — poster-shaped portraits on iOS/macOS, TVUIKit monogram circles
  /// on tvOS. **Actors only, and fiction only.** Directors were on it, and first: a
  /// name people know and a face they do not, taking the opening slot of the one
  /// section that is about faces. They read as a line in Credits instead.
  public var showsCastPortraits: Bool { kind == .fiction }

  /// The rail's header. It holds the cast and nothing else now, so it says so.
  public var castSectionTitleKey: String { "MediaItem_CastSection" }

  /// The hero's "Starring …" line, under the synopsis. Off wherever there is no
  /// starring to speak of — nobody stars in a stand-up set.
  public var showsHeroCastLine: Bool { kind == .fiction }

  /// The Credits row naming whoever made it.
  public var authorCaptionKey: String {
    authorRole == .creator ? "MediaItem_Creators" : "Director"
  }

  /// "More from …" for the people in the `director` field. A concert's or a stand-up
  /// set's director is a TV credit nobody is following, so those get no such shelf.
  public var showsAuthorShelf: Bool { kind != .concert && kind != .standup }

  /// One name or several — the shelf asks for all of them at once, so with more than
  /// one there is no single person to name in the header.
  public func authorShelfTitleKey(count: Int) -> String {
    switch (authorRole, count > 1) {
    case (.director, false): return "MediaItem_MoreByDirector"
    case (.director, true): return "MediaItem_MoreByDirectors"
    case (.creator, false): return "MediaItem_MoreByCreator"
    case (.creator, true): return "MediaItem_MoreByCreators"
    }
  }

  // MARK: - Related shelves

  /// Whether the cast is worth a shelf at all. **Not for animation**: kino.pub's `cast`
  /// on a cartoon or an anime is the voice actors, and "More with Уэмура Юто" over a
  /// wall of unrelated anime is a shelf built on a name the viewer never heard and a
  /// face that was never on screen.
  public var showsCastShelf: Bool { kind != .animation }

  /// Who the cast shelf asks for, and what it accepts back.
  public var castShelf: CastShelfPolicy {
    switch kind {
    // The people on stage *are* the title. Ask them for concerts: a singer's
    // filmography is not what someone watching a concert wants next.
    case .concert:
      return CastShelfPolicy(nameLimit: 2, onlyType: .concert, preferredTypes: [])
    // A comic's other work is the interesting answer, and it is usually a film or a
    // series rather than another set — so nothing is filtered out, only ordered.
    case .standup:
      return CastShelfPolicy(nameLimit: 2, onlyType: nil, preferredTypes: [.movie, .serial])
    // The billed lead. Two names is a shelf; a film credits fifteen.
    case .fiction, .documentary, .show:
      return CastShelfPolicy(nameLimit: 1, onlyType: nil, preferredTypes: [])
    case .animation:
      return CastShelfPolicy(nameLimit: 0, onlyType: nil, preferredTypes: [])
    }
  }

  /// Header for the cast shelf. Only the stage kinds get a role-worded one; elsewhere
  /// the shelf names the single actor it asked for, which reads better.
  public func castShelfTitleKey(count: Int) -> String? {
    switch (kind, count > 1) {
    case (.concert, false): return "MediaItem_MoreFromArtist"
    case (.concert, true): return "MediaItem_MoreFromArtists"
    case (.standup, false): return "MediaItem_MoreFromComedian"
    case (.standup, true): return "MediaItem_MoreFromComedians"
    default: return nil
    }
  }

  /// The genre shelf is the last resort under the related area: it fires only when
  /// credits, collections and similar all came back with nothing, which is the normal
  /// state of a TV show, a concert or a stand-up set and the rare state of a film.
  ///
  /// **How many genres.** A film asks for one — "more comedy" under a comedy is a
  /// truism, and its other shelves carry the page anyway. Everything else asks for all
  /// of them at once (`genre=5,23,101` is OR), because a title filed under six genres
  /// is described by the combination and not by whichever one came first.
  public var genreShelfUsesEveryGenre: Bool { kind != .fiction }

  /// Which genre leads when only one is asked for: the one that decided the title's
  /// kind — a stand-up set is filed under Comedy *and* 101, and 101 is the one worth
  /// asking about.
  public var signatureGenreIDs: Set<Int> {
    switch kind {
    case .standup: return Self.standupGenreIDs
    case .animation: return Self.animationGenreIDs
    default: return []
    }
  }
}

/// How a title's cast becomes a shelf query.
public struct CastShelfPolicy: Equatable, Sendable {
  /// How many credited names the shelf asks about — **one request each**, so this is
  /// also how many requests it costs. Zero means no cast shelf.
  public let nameLimit: Int
  /// Narrow the query to a single type where the type is the point.
  public let onlyType: MediaType?
  /// Not a filter — an ordering. These float to the front of whatever comes back.
  public let preferredTypes: [MediaType]

  public init(nameLimit: Int, onlyType: MediaType?, preferredTypes: [MediaType]) {
    self.nameLimit = nameLimit
    self.onlyType = onlyType
    self.preferredTypes = preferredTypes
  }
}

// MARK: - Reading the kind off an item

public extension MediaPresentationProfile {

  /// Type first, then genre: a `documovie` is a documentary whatever its genres say,
  /// while a documentary, a cartoon or a stand-up set filed as a plain `movie` is only
  /// knowable from the genre list.
  ///
  /// Genres 101 (stand-up) and 23 (animation) are the ids kino.pub has confirmed to us.
  /// The rest match on the genre's own title, in both languages the API answers in,
  /// because we hold no id table for them (`filter.genres` in `kpapp.link/config.json`
  /// is where one would come from — see docs/providers/kinopub/references.md).
  init(type: String, genres: [TypeClass]) {
    self.init(kind: Self.kind(type: type, genres: genres),
              authorRole: Self.authorRole(type: type),
              isAnime: Self.isAnime(genres: genres))
  }

  /// kino.pub files anime as a **genre**, not a type — `MediaType` has no case for it —
  /// and we hold no confirmed id for it the way we do for 23 (`Мультфильм`) and 101
  /// (stand-up), so this matches the genre's own title in both languages the API answers
  /// in. A cartoon is deliberately not anime.
  private static func isAnime(genres: [TypeClass]) -> Bool {
    let titles = genres.compactMap(\.title).map(normalized)
    return titles.contains { matches($0, animeGenreWords) }
  }

  private static func kind(type: String, genres: [TypeClass]) -> MediaPresentationKind {
    switch type.lowercased() {
    case "documovie", "docuserial": return .documentary
    case "concert": return .concert
    case "tvshow": return .show
    default: break
    }

    let ids = Set(genres.map(\.id))
    if !ids.isDisjoint(with: standupGenreIDs) { return .standup }
    if !ids.isDisjoint(with: animationGenreIDs) { return .animation }

    let titles = genres.compactMap(\.title).map(normalized)
    if titles.contains(where: { matches($0, animationGenreWords) }) { return .animation }
    if titles.contains(where: { matches($0, documentaryGenreWords) }) { return .documentary }
    if titles.contains(where: { matches($0, standupGenreWords) }) { return .standup }

    return .fiction
  }

  /// Episodic and documentary titles credit creators; a film credits a director.
  /// `documovie` is not episodic and still counts — its `director` is its author.
  private static func authorRole(type: String) -> MediaAuthorRole {
    switch type.lowercased() {
    case "serial", "docuserial", "tvshow", "documovie": return .creator
    default: return .director
    }
  }

  private static func normalized(_ title: String) -> String {
    title.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                  locale: nil)
  }

  private static func matches(_ title: String, _ words: [String]) -> Bool {
    words.contains { title.contains($0) }
  }

  /// Confirmed by the user against live payloads: 101 stand-up, 23 "Мультфильм".
  private static let standupGenreIDs: Set<Int> = [101]
  private static let animationGenreIDs: Set<Int> = [23]
  private static let standupGenreWords = ["стендап", "стенд-ап", "stand-up", "standup"]
  private static let animeGenreWords = ["аниме", "anime"]
  private static let cartoonGenreWords = ["мультфильм", "мультсериал", "cartoon", "animation"]
  private static let animationGenreWords = animeGenreWords + cartoonGenreWords
  private static let documentaryGenreWords = ["документальн", "documentar"]
}

public extension Array where Element == MediaItem {
  /// Preferred types to the front, everything else after, each keeping its incoming
  /// order — an ordering, never a filter, so a shelf can favour films without hiding
  /// the rest. Comparison is on the raw type, lowercased: kino.pub answers `"3d"`
  /// where `MediaType.threeD` is `"3D"`.
  func preferringTypes(_ types: [MediaType]) -> [MediaItem] {
    guard !types.isEmpty else { return self }
    let preferred = Set(types.map { $0.rawValue.lowercased() })
    let (front, back) = reduce(into: ([MediaItem](), [MediaItem]())) { acc, item in
      if preferred.contains(item.type.lowercased()) {
        acc.0.append(item)
      } else {
        acc.1.append(item)
      }
    }
    return front + back
  }
}

public extension MediaItem {
  /// How this title should be presented. Ask this, never `type` directly.
  var presentation: MediaPresentationProfile {
    MediaPresentationProfile(type: type, genres: genres)
  }
}
