//
//  MediaCard+Episode.swift
//  KinoPubUI
//
//  One mapping from an episode to the landscape card History and Continue Watching
//  already draw, so the detail rail and the season grid stop growing lookalikes.
//

import Foundation
import KinoPubBackend

public extension MediaCard {

  /// An episode as a landscape `MediaCard`.
  ///
  /// The caller owns the strings the payload cannot compose on its own: `title`
  /// (kino.pub's name, or a schedule's when the episode has none), `episodeLabel`
  /// ("Episode 9") and `dateLabel` (already formatted — the UI package does not know
  /// this app's date rules). `stillURL` overrides the episode thumbnail when an
  /// external schedule carries a better one.
  ///
  /// A name that is only the episode's own number — "Эпизод 1" against
  /// `Episode 1`, whatever the UI language — is treated as no name at all, so the
  /// caption never says the same thing twice.
  init(episode: Episode,
       in season: Season? = nil,
       title: String? = nil,
       episodeLabel: String? = nil,
       dateLabel: String? = nil,
       stillURL: String? = nil,
       primaryAction: MediaCardPrimaryAction = .play) {
    let still = stillURL ?? episode.thumbnail
    let isWatched = episode.isWatched
    // Resume bar only while unfinished — a watched episode says so with the time chip.
    // `resumeFraction` already applied the start floor and credits window.
    let progress = isWatched ? nil : episode.watchProgress.resumeFraction
    let caption = Self.episodeCaption(name: title ?? episode.title,
                                      number: episode.number,
                                      episodeLabel: episodeLabel,
                                      dateLabel: dateLabel,
                                      fallbackTitle: episode.fixedTitle)

    self.init(id: episode.id,
              posterURL: still,
              title: caption.title,
              progress: progress,
              landscapeImageURL: still,
              overlayLabel: caption.meta,
              itemID: season?.mediaId ?? episode.mediaId ?? episode.id,
              video: episode.number,
              season: season?.number ?? episode.seasonNumber,
              mediaID: episode.id,
              isWatched: isWatched,
              isSeries: true,
              durationSeconds: episode.duration >= 60 ? episode.duration : nil,
              primaryAction: primaryAction)
  }

  /// A landscape card for an episode that exists only on a schedule — announced or
  /// simply not uploaded yet. Inert: nothing to play, so Select opens nothing.
  ///
  /// `id` is the caller's synthetic (negative) rail id, kept outside kino.pub's ids.
  init(unavailableEpisodeID id: Int,
       number: Int,
       title: String?,
       episodeLabel: String?,
       dateLabel: String?,
       stillURL: String?) {
    let still = stillURL ?? ""
    let caption = Self.episodeCaption(name: title ?? "",
                                      number: number,
                                      episodeLabel: episodeLabel,
                                      dateLabel: dateLabel,
                                      fallbackTitle: episodeLabel ?? "")
    self.init(id: id,
              posterURL: still,
              title: caption.title,
              landscapeImageURL: still,
              overlayLabel: caption.meta,
              isSeries: true,
              primaryAction: .openDetail)
  }

  /// Title line + meta line for an episode caption.
  ///
  /// Named episode → name on top, "Episode 9 · 5 Mar 2026" under it. Unnamed (or named
  /// after its own number) → "Episode 9" is the title and the date stands alone, so the
  /// two lines never repeat each other.
  private static func episodeCaption(name: String,
                                     number: Int,
                                     episodeLabel: String?,
                                     dateLabel: String?,
                                     fallbackTitle: String) -> (title: String, meta: String?) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasName = !trimmed.isEmpty && !isOwnNumber(trimmed, number: number)
    guard hasName else {
      return (episodeLabel ?? fallbackTitle, dateLabel)
    }
    let meta = [episodeLabel, dateLabel]
      .compactMap { $0?.isEmpty == false ? $0 : nil }
      .joined(separator: " · ")
    return (trimmed, meta.isEmpty ? nil : meta)
  }

  /// True for "Эпизод 1" / "Серия 1" / "Episode 1" / "Ep. 1" on episode 1 — a name that
  /// only restates the number the caption already carries, in any of our languages.
  private static func isOwnNumber(_ name: String, number: Int) -> Bool {
    let words: Set<String> = ["эпизод", "серия", "серія", "episode", "ep", "e", "serija", "sezonas"]
    let parts = name
      .lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
    guard parts.count == 2 else { return false }
    let hasWord = parts.contains { words.contains($0) }
    let hasNumber = parts.contains { Int($0) == number }
    return hasWord && hasNumber
  }
}
