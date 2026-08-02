//
//  StreamSurvey.swift
//  KinoPubAppleClient
//
//  Created by Sasha Romanov on 24.07.2026.
//

#if DEBUG
import Foundation
import KinoPubBackend
import KinoPubLogging
import OSLog

/// Walks a sample of the catalogue and records what kino.pub actually ships, so the
/// "do we need FFmpeg?" question gets answered with data instead of guesses.
///
/// Two things are counted separately and they are not the same thing:
/// - **source**, from the API (`FileInfo.codec`, `VideoAudio.codec/channels`)
/// - **delivered**, from the `hls4` master playlist's `CODECS` / `CHANNELS` attributes
///
/// AVFoundation only ever sees the delivered stream. A library full of DTS sources that
/// kino.pub re-encodes to AC-3 for HLS costs us nothing; a single DTS rendition that
/// survives into the manifest is a stream that silently plays without sound today.
@MainActor
final class StreamSurveyModel: ObservableObject {

  @Published private(set) var isRunning = false
  @Published private(set) var status: String = "Not run yet."
  @Published private(set) var report: String = ""

  private var tally = Tally()

  func run(service: VideoContentService, limit: Int = 40) async {
    guard !isRunning else { return }
    isRunning = true
    tally = Tally()
    report = ""
    defer { isRunning = false }

    status = "Collecting items…"
    let ids = await collectItemIDs(service: service, limit: limit)
    guard !ids.isEmpty else {
      status = "No items came back — is the session still valid?"
      return
    }

    for (index, id) in ids.enumerated() {
      status = "Probing \(index + 1)/\(ids.count)…"
      await probe(id: id, service: service)
    }

    report = tally.summary
    status = "Done — \(tally.itemsScanned) items, \(tally.manifestsFetched) manifests."
    Logger.app.info("Stream survey\n\(self.report, privacy: .public)")
  }

  // MARK: - Collection

  private func collectItemIDs(service: VideoContentService, limit: Int) async -> [Int] {
    var ids: [Int] = []
    var seen: Set<Int> = []

    // A spread rather than one list: "hot" skews to new releases, "popular" to the
    // back catalogue, and the two encode differently often enough to matter.
    for shortcut in MediaShortcut.allCases {
      for type in [MediaType.movie, .serial] {
        guard ids.count < limit else { break }
        do {
          let page = try await service.fetch(shortcut: shortcut, contentType: type, page: 1)
          for item in page.items where seen.insert(item.id).inserted {
            ids.append(item.id)
            if ids.count >= limit { break }
          }
        } catch {
          tally.notes.append("List \(shortcut.rawValue)/\(type.rawValue) failed: \(error)")
        }
      }
    }

    return ids
  }

  // MARK: - Probing

  private func probe(id: Int, service: VideoContentService) async {
    let item: MediaItem
    do {
      item = try await service.fetchDetails(for: String(id)).item
    } catch {
      tally.itemsFailed += 1
      return
    }

    // Movies carry a single video; for a serial the first episode is representative
    // enough for a codec census.
    guard let video = item.videos?.first else {
      tally.notes.append("#\(id) \(item.title): no videos in details")
      tally.itemsFailed += 1
      return
    }

    tally.itemsScanned += 1

    for file in video.files {
      tally.sourceVideoCodecs[file.codec.lowercased(), default: 0] += 1
      tally.sourceQualities[file.quality, default: 0] += 1
      if let ext = fileExtension(of: file.url.http) {
        tally.directFileExtensions[ext, default: 0] += 1
      }
    }

    for audio in video.audios {
      tally.sourceAudioCodecs[audio.codec.lowercased(), default: 0] += 1
      tally.sourceAudioChannels[audio.channels, default: 0] += 1
    }

    for subtitle in video.subtitles {
      let kind = subtitle.embed ? "embedded" : (fileExtension(of: subtitle.url) ?? "sidecar")
      tally.subtitleKinds[kind, default: 0] += 1
    }

    await probeManifest(for: video, title: item.title, id: id)
  }

  private func probeManifest(for video: Video, title: String, id: Int) async {
    // Deliberately the top quality rather than `BestVideoQualityFinder`'s device-appropriate
    // pick: HDR, Dolby Vision and multichannel dubs live at the top of the ladder, and it is
    // exactly those we are hunting for.
    guard let file = video.files.last, let url = URL(string: file.url.hls4) else {
      tally.manifestsFailed += 1
      return
    }

    do {
      let (data, response) = try await URLSession.shared.data(from: url)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        tally.manifestsFailed += 1
        tally.notes.append("#\(id) \(title): manifest HTTP \(http.statusCode)")
        return
      }
      guard let text = String(data: data, encoding: .utf8) else {
        tally.manifestsFailed += 1
        return
      }

      let manifest = HLSManifestParser.parse(text)
      guard !manifest.variants.isEmpty || !manifest.renditions.isEmpty else {
        // A media playlist rather than a master: no CODECS to read at all.
        tally.mediaPlaylistsSeen += 1
        return
      }

      tally.manifestsFetched += 1
      record(manifest)
    } catch {
      tally.manifestsFailed += 1
      tally.notes.append("#\(id) \(title): \(error.localizedDescription)")
    }
  }

  private func record(_ manifest: HLSManifest) {
    for variant in manifest.variants {
      for codec in variant.codecs {
        let family = CodecNames.family(of: codec)
        if CodecNames.isAudio(family) {
          tally.manifestAudioCodecs[family, default: 0] += 1
        } else {
          tally.manifestVideoCodecs[family, default: 0] += 1
        }
      }
      tally.videoRanges[variant.videoRange  ?? "(absent — SDR)", default: 0] += 1
      if let rate = variant.frameRate { tally.frameRates[rate, default: 0] += 1 }
      if let resolution = variant.resolution { tally.resolutions[resolution, default: 0] += 1 }
    }

    for rendition in manifest.renditions {
      switch rendition.type {
      case "AUDIO":
        tally.manifestAudioRenditions += 1
        tally.manifestAudioChannels[rendition.channels ?? "(absent)", default: 0] += 1
      case "SUBTITLES":
        tally.manifestSubtitleRenditions += 1
      case "CLOSED-CAPTIONS":
        tally.manifestClosedCaptions += 1
      default:
        break
      }
    }
  }

  private func fileExtension(of urlString: String) -> String? {
    guard let url = URL(string: urlString) else { return nil }
    let ext = url.pathExtension.lowercased()
    return ext.isEmpty ? nil : ext
  }
}

// MARK: - Tally

private struct Tally {
  var itemsScanned = 0
  var itemsFailed = 0

  var sourceVideoCodecs: [String: Int] = [:]
  var sourceAudioCodecs: [String: Int] = [:]
  var sourceAudioChannels: [Int: Int] = [:]
  var sourceQualities: [String: Int] = [:]
  var directFileExtensions: [String: Int] = [:]
  var subtitleKinds: [String: Int] = [:]

  var manifestsFetched = 0
  var manifestsFailed = 0
  var mediaPlaylistsSeen = 0
  var manifestVideoCodecs: [String: Int] = [:]
  var manifestAudioCodecs: [String: Int] = [:]
  var manifestAudioChannels: [String: Int] = [:]
  var videoRanges: [String: Int] = [:]
  var frameRates: [String: Int] = [:]
  var resolutions: [String: Int] = [:]
  var manifestAudioRenditions = 0
  var manifestSubtitleRenditions = 0
  var manifestClosedCaptions = 0

  var notes: [String] = []

  var summary: String {
    var lines: [String] = []

    lines.append("SCANNED  \(itemsScanned) items (\(itemsFailed) failed)")
    lines.append("MANIFEST \(manifestsFetched) fetched, \(manifestsFailed) failed, \(mediaPlaylistsSeen) were media playlists")
    lines.append("")

    lines.append("— DELIVERED (hls4 master playlist) —")
    lines.append(section("video codecs", manifestVideoCodecs, verdict: CodecNames.avPlaybackVerdict))
    lines.append(section("audio codecs", manifestAudioCodecs, verdict: CodecNames.avPlaybackVerdict))
    lines.append(section("VIDEO-RANGE", videoRanges))
    lines.append(section("resolutions", resolutions))
    lines.append(section("frame rates", frameRates))
    lines.append(section("audio CHANNELS attr", manifestAudioChannels))
    lines.append("audio renditions: \(manifestAudioRenditions), subtitle renditions: \(manifestSubtitleRenditions), CC: \(manifestClosedCaptions)")
    lines.append("")

    lines.append("— SOURCE (API metadata) —")
    lines.append(section("video codecs", sourceVideoCodecs, verdict: CodecNames.avPlaybackVerdict))
    lines.append(section("audio codecs", sourceAudioCodecs, verdict: CodecNames.avPlaybackVerdict))
    lines.append(section("audio channels", sourceAudioChannels.reduce(into: [String: Int]()) { $0["\($1.key) ch"] = $1.value }))
    lines.append(section("qualities", sourceQualities))
    lines.append(section("direct-file extensions (url.http)", directFileExtensions))
    lines.append(section("subtitle kinds", subtitleKinds))

    if !notes.isEmpty {
      lines.append("")
      lines.append("— NOTES —")
      lines.append(contentsOf: notes.prefix(20))
    }

    return lines.joined(separator: "\n")
  }

  private func section(_ title: String,
                       _ counts: [String: Int],
                       verdict: ((String) -> String)? = nil) -> String {
    guard !counts.isEmpty else { return "\(title): —" }
    let body = counts
      .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
      .map { key, count in
        let mark = verdict.map { " \($0(key))" } ?? ""
        return "    \(key)\(mark) × \(count)"
      }
      .joined(separator: "\n")
    return "\(title):\n\(body)"
  }
}

// MARK: - Codec naming

enum CodecNames {

  /// `avc1.640028` → `avc1`, `mp4a.40.2` → `mp4a`. API values like `h264` pass through.
  static func family(of codec: String) -> String {
    String(codec.split(separator: ".").first ?? "").lowercased()
  }

  private static let audioFamilies: Set<String> = [
    "mp4a", "ac-3", "ac3", "ec-3", "eac3", "alac", "flac", "fLaC", "opus", "dts", "dtsc",
    "dtse", "dtsh", "dtsl", "dtshd", "mlpa", "truehd", "mp3", "vorbis", "pcm"
  ]

  static func isAudio(_ family: String) -> Bool {
    audioFamilies.contains(family.lowercased())
  }

  /// Can AVFoundation on tvOS play this? `?` means genuinely uncertain and worth a look
  /// rather than a guess.
  static func avPlaybackVerdict(_ family: String) -> String {
    switch family.lowercased() {
    case "avc1", "avc3", "h264", "hvc1", "hev1", "hevc", "h265",
         "dvh1", "dvhe",
         "mp4a", "aac", "ac-3", "ac3", "ec-3", "eac3", "alac":
      return "✅"
    case "dts", "dtsc", "dtse", "dtsh", "dtsl", "dtshd", "dtsma",
         "mlpa", "truehd", "vorbis", "vc-1", "vc1", "wmv3":
      return "❌"
    case "flac", "opus", "mp3", "vp09", "vp9", "av01", "av1", "pcm":
      return "❓"
    default:
      return "❓"
    }
  }
}
#endif
