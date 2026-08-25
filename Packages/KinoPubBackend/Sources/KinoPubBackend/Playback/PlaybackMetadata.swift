//
//  PlaybackMetadata.swift
//
//

import AVFoundation
import Foundation

/// **What the system player is told about what is playing.**
///
/// `AVPlayerItem.externalMetadata` is the whole of the tvOS info panel, the iOS Now Playing
/// screen, Control Center, the lock screen and what AirPlay hands the receiver. Filling it
/// is not chrome we draw — it is the stock surface, populated.
///
/// A pure mapping from our model, so what ends up in the panel can be asserted without an
/// asset, a player or a device.
///
/// **What is not here, deliberately:** capability badges (4K, HDR, Atmos). There is no
/// metadata identifier for them — the common and iTunes identifier sets carry title,
/// subtitle, description, genre, date, artwork and the like, and nothing that draws a
/// badge. On tvOS the supported way to put our own facts in that panel is
/// `customInfoViewControllers`, a tab of our own; see ROADMAP stage 7.
public enum PlaybackMetadata {

  /// - Parameters:
  ///   - title: the film, or the **series** for an episode.
  ///   - subtitle: "Season 2, Episode 5 — name", or nothing for a film.
  ///   - context: the item this playback belongs to. For an episode that is its series:
  ///     an `Episode` carries none of its parent's context — no plot, no genres, no year —
  ///     so without this the info panel of the surface that uses it most, a series, showed
  ///     two lines and nothing else.
  public static func items(title: String?,
                           subtitle: String?,
                           context: MediaItem?) -> [AVMetadataItem] {
    var items: [AVMetadataItem] = []
    if let title, !title.isEmpty {
      items.append(item(.commonIdentifierTitle, title))
    }
    if let subtitle, !subtitle.isEmpty {
      items.append(item(.iTunesMetadataTrackSubTitle, subtitle))
    }
    guard let context else { return items }

    if !context.plot.isEmpty {
      items.append(item(.commonIdentifierDescription, context.plot))
    }
    let genres = context.genres.compactMap(\.title).filter { !$0.isEmpty }
    if !genres.isEmpty {
      items.append(item(.commonIdentifierType, genres.joined(separator: ", ")))
    }
    if context.year > 0 {
      // A year, not a date: the API has no release day, and inventing one would be a
      // fact we do not have.
      items.append(item(.commonIdentifierCreationDate, String(context.year)))
    }
    return items
  }

  /// The artwork to show beside all that: the title's poster, falling back to whatever the
  /// playing thing offers on its own — an episode still, when the series is not at hand.
  public static func artworkURL(context: MediaItem?, fallback: String? = nil) -> URL? {
    let candidates = [context?.posters.big, context?.posters.medium, context?.posters.small,
                      fallback]
    return candidates
      .compactMap { $0 }
      .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .flatMap(URL.init(string:))
  }

  /// Artwork arrives as bytes rather than a URL — the panel wants the image itself.
  public static func artworkItem(_ data: Data) -> AVMetadataItem {
    let artwork = AVMutableMetadataItem()
    artwork.identifier = .commonIdentifierArtwork
    artwork.value = data as NSData
    artwork.dataType = kCMMetadataBaseDataType_JPEG as String
    artwork.extendedLanguageTag = "und"
    return artwork
  }

  private static func item(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.identifier = identifier
    item.value = value as NSString
    // "und" rather than a language: these are not translations of each other, and a tagged
    // language makes AVFoundation filter them against the viewer's own.
    item.extendedLanguageTag = "und"
    return item
  }
}
