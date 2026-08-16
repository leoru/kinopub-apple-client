//
//  MediaItem+Variants.swift
//
//

import Foundation

// MARK: - One film, several catalogue entries

public extension MediaItem {

  /// The 3D encoding of a film is its own catalogue entry, with its own id, filed
  /// under the same director and the same cast as the flat one — so a person listing
  /// answers with both, usually next to each other.
  var is3D: Bool {
    type.caseInsensitiveCompare(MediaType.threeD.rawValue) == .orderedSame
      || subtype.localizedCaseInsensitiveContains("3d")
  }

  /// Identity of the **film**, not of this entry: every copy of one title shares it.
  ///
  /// The external ids are what kino.pub actually fills in for both copies — `Лего.
  /// Фильм 3D` (#9072) and `ЛЕГО Фильм` (#7319) are both kinopoisk 471644, imdb
  /// 1490017 — so they, not the title, decide. The title+year fallback is for entries
  /// that carry neither id, and normalizes away the "3D" the copy usually adds to its
  /// title along with case, punctuation and spacing.
  var filmIdentity: String {
    if let kinopoisk, kinopoisk > 0 { return "kp:\(kinopoisk)" }
    if let imdb, imdb > 0 { return "imdb:\(imdb)" }
    return "t:\(Self.identityTitle(title))|\(year)"
  }

  private static func identityTitle(_ title: String) -> String {
    title
      .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty && $0 != "3d" }
      .joined(separator: " ")
  }

  /// Which of two copies of the same film should represent it. 3D-ness first — the
  /// caller says which side it wants, so a 3D page's shelves stay 3D — then the copy
  /// that is simply the better file, and finally the one people actually watch.
  func isBetterCopy(than other: MediaItem, preferring3D: Bool) -> Bool {
    if is3D != other.is3D { return is3D == preferring3D }
    if quality != other.quality { return quality > other.quality }
    if langs != other.langs { return langs > other.langs }
    if views != other.views { return views > other.views }
    return id > other.id
  }
}

public extension Array where Element == MediaItem {

  /// One card per film. Keeps the first copy's position in the list and swaps in the
  /// better copy when a later one turns up, so a rating-ordered answer stays
  /// rating-ordered.
  ///
  /// - Parameter preferring3D: keep the 3D copy where there is a choice. What the page
  ///   the user is on is: a 3D title's shelves should not offer flat copies of the
  ///   films it lists, and everywhere else 3D is the odd one out.
  func collapsingFilmVariants(preferring3D: Bool = false) -> [MediaItem] {
    var indexByFilm: [String: Int] = [:]
    var kept: [MediaItem] = []
    kept.reserveCapacity(count)
    for item in self {
      let identity = item.filmIdentity
      guard let index = indexByFilm[identity] else {
        indexByFilm[identity] = kept.count
        kept.append(item)
        continue
      }
      if item.isBetterCopy(than: kept[index], preferring3D: preferring3D) {
        kept[index] = item
      }
    }
    return kept
  }

  /// Newest first, which is how a filmography reads. Ties — a director with three
  /// releases in one year — fall back to views.
  ///
  /// Views, not a rating: a score is only as good as the crowd behind it, and kino.pub
  /// reports neither vote count as something we can trust to be there — a title with 5
  /// Kinopoisk votes would jump a title with a million on IMDb. How many people here
  /// opened it is the honest "known for" signal, and it is never missing.
  func sortedNewestFirst() -> [MediaItem] {
    sorted {
      if $0.year != $1.year { return $0.year > $1.year }
      return $0.views > $1.views
    }
  }
}
