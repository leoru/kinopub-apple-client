//
//  HLSAudioLabeler.swift
//  KinoPubAppleClient
//
//  Rewrites a kino.pub HLS master so audio renditions carry useful names.
//
//  Two problems with the raw master. One: the CDN names renditions after the
//  track ("01. Многоголосый. Rezka (RUS)"), which reads as noise in the system
//  picker — the API already knows the dub kind and studio, so we stamp a clean
//  label in ("Русский ∙ Многоголосый, Rezka"). Two, the expensive one: the same
//  renditions are repeated once per video quality under per-quality GROUP-IDs
//  (audio1080 / audio720 / audio480). AVFoundation merges every audio group into
//  one selection group, so each track appears once per quality — identical rows,
//  and switching between the copies changes nothing. The rewrite drops a rendition
//  only when an earlier survivor carries the same NAME under a *different* group
//  (the per-quality copy) or the same NAME and URI (a literal repeat): a repeated
//  name within one group is a distinct track the CDN didn't name, and the API
//  match gives it a real one. Survivors move into one group, and every variant
//  stream is pointed at it.
//
//  What we write arrives as the selection option's common-metadata title — read
//  it with `AVMediaSelectionOption.kinopubTrackName`, not `displayName`, which
//  discards it (see that property's note). Child playlist URIs are made absolute
//  because the rewritten master is served from memory, not from the CDN.
//
//  Delivery is `HLSMasterResourceLoader` below: AVPlayer requests the master
//  through a custom scheme, the loader fetches and rewrites it inline, and any
//  problem degrades to the CDN's own bytes. An earlier version wrote the
//  rewritten master to a `file://` temp path instead — AVFoundation never
//  finishes loading a file-URL master whose media is remote (the item just sits
//  in `.unknown`), which showed up as every film spinning forever while
//  trailers, which skip the rewrite, played fine.
//

import AVFoundation
import Foundation
import KinoPubBackend
import KinoPubLogging
import OSLog

enum HLSAudioLabeler {

  /// Older builds wrote rewritten masters under tmp and never deleted them.
  /// One sweep at launch clears whatever they left behind.
  static func removeLegacyTemporaryFiles() {
    try? FileManager.default.removeItem(at: legacyTemporaryDirectory)
  }

  static var legacyTemporaryDirectory: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("kinopub-hls", isDirectory: true)
  }

  /// Bytes still sitting in the legacy scratch directory — for the Settings storage screen.
  /// Normally 0: `removeLegacyTemporaryFiles()` already sweeps this at every launch.
  static var legacyTemporaryDirectorySize: Int64 {
    guard let enumerator = FileManager.default.enumerator(
      at: legacyTemporaryDirectory, includingPropertiesForKeys: [.fileSizeKey]
    ) else { return 0 }
    var total: Int64 = 0
    for case let url as URL in enumerator {
      let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
      total += Int64(size ?? 0)
    }
    return total
  }

  /// Pure rewrite for tests: collapses per-quality audio duplicates, replaces AUDIO
  /// `NAME`s, absolute-izes relative URIs.
  static func rewrite(_ playlist: String,
                      baseURL: URL,
                      tracks: [AudioTrackInfo],
                      preferredLanguages: [String] = Locale.preferredLanguages) -> String {
    let lines = playlist.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let audioIndices = lines.indices.filter { isAudioMedia(lines[$0]) }
    guard !audioIndices.isEmpty else {
      return absolutize(lines, baseURL: baseURL).joined(separator: "\n")
    }

    // Keep the first occurrence of each distinct NAME *across* groups — a repeat under
    // another GROUP-ID is the per-quality copy of the same track. A repeated name
    // within one group is NOT a copy: the CDN left two dubs unnamed, and the API match
    // below gives each its real one (LostFilm next to Red Head Sound, say). A literal
    // repeat — same NAME, same URI — is a duplicate wherever it sits. All survivors
    // move into one group.
    var keepers: [Int] = []
    var keeperAttrs: [[String: String]] = []
    var audioGroupIDs: Set<String> = []
    var unifiedGroupID: String?
    for index in audioIndices {
      let attrs = attributes(in: lines[index])
      if unifiedGroupID == nil { unifiedGroupID = attrs["GROUP-ID"] }
      if let group = attrs["GROUP-ID"] { audioGroupIDs.insert(group) }
      let name = attrs["NAME"] ?? ""
      let isCopy = !name.isEmpty && keeperAttrs.contains { keeper in
        keeper["NAME"] == name
          && (keeper["GROUP-ID"] != attrs["GROUP-ID"] || keeper["URI"] == attrs["URI"])
      }
      if name.isEmpty || !isCopy {
        keepers.append(index)
        keeperAttrs.append(attrs)
      }
    }

    let (labels, matched) = labelsForKeepers(keeperAttrs, tracks: tracks)
    let defaultKeeper = bestKeeper(matched: matched, preferredLanguages: preferredLanguages)

    var keeperPosition: [Int: Int] = [:]
    for (position, index) in keepers.enumerated() { keeperPosition[index] = position }

    var out: [String] = []
    out.reserveCapacity(lines.count)
    for (index, line) in lines.enumerated() {
      if let position = keeperPosition[index] {
        var line = line
        if let unifiedGroupID {
          line = replaceAttribute("GROUP-ID", with: unifiedGroupID, in: line)
        }
        line = replaceName(in: line, with: labels[position])
        if let defaultKeeper {
          line = setDefault(line, isDefault: position == defaultKeeper)
        }
        out.append(line)
      } else if isAudioMedia(line) {
        continue // per-quality copy of a keeper
      } else if line.hasPrefix("#EXT-X-STREAM-INF:"),
                let unifiedGroupID,
                let group = attributes(in: line)["AUDIO"],
                audioGroupIDs.contains(group) {
        out.append(replaceAttribute("AUDIO", with: unifiedGroupID, in: line))
      } else {
        out.append(line)
      }
    }
    return absolutize(out, baseURL: baseURL).joined(separator: "\n")
  }

  // MARK: - Track matching

  /// Matches surviving renditions to API tracks: first by the leading number the CDN
  /// prefixes names with ("01. …" ↔ `AudioTrackInfo.index` 1), then by language —
  /// several same-language tracks go in the site's own listing order (payload
  /// `index`). An unmatched survivor keeps its CDN name — "01. Многоголосый.
  /// Rezka (RUS)" says more than a bare language row.
  private static func labelsForKeepers(_ attrs: [[String: String]],
                                       tracks: [AudioTrackInfo]) -> (labels: [String], matched: [AudioTrackInfo?]) {
    var remaining = tracks
    var matched = [AudioTrackInfo?](repeating: nil, count: attrs.count)
    for (index, attr) in attrs.enumerated() {
      guard let trackIndex = leadingIndex(attr["NAME"] ?? ""),
            let t = remaining.firstIndex(where: { $0.index == trackIndex }) else { continue }
      matched[index] = remaining.remove(at: t)
    }
    for (index, attr) in attrs.enumerated() where matched[index] == nil {
      let key = SubtitleTracks.languageKey(attr["LANGUAGE"] ?? "")
      guard !key.isEmpty else { continue }
      // Several same-language tracks and no rendition numbers: take them in payload
      // order (`index` is the site's own listing order), not fixture order.
      let candidates = remaining.indices.filter { SubtitleTracks.languageKey(remaining[$0].lang) == key }
      guard let t = candidates.min(by: { remaining[$0].index < remaining[$1].index }) else { continue }
      matched[index] = remaining.remove(at: t)
    }
    let labels: [String] = attrs.enumerated().map { index, attr in
      if let track = matched[index] { return AudioTracks.baseLabel(track) }
      if let name = attr["NAME"], !name.isEmpty { return name }
      if let language = attr["LANGUAGE"], !language.isEmpty { return LanguageNames.name(for: language) }
      return "Audio"
    }
    return (AudioTracks.uniquedHLSLabels(labels), matched)
  }

  /// Leading rendition number the CDN prefixes names with: `"01. Многоголосый…"` → 1.
  private static func leadingIndex(_ name: String) -> Int? {
    let digits = name.prefix(while: { $0.isNumber })
    guard !digits.isEmpty else { return nil }
    let rest = name.dropFirst(digits.count)
    guard let separator = rest.first, separator == "." || separator == ")" || separator == " " else { return nil }
    return Int(digits)
  }

  // MARK: - DEFAULT pick

  private static func bestKeeper(matched: [AudioTrackInfo?], preferredLanguages: [String]) -> Int? {
    var bestIndex: Int?
    var bestKey: AudioTracks.SortKey?
    for (index, track) in matched.enumerated() {
      guard let track else { continue }
      let key = AudioTracks.sortKey(for: track, preferredLanguages: preferredLanguages)
      if bestKey == nil || key < bestKey! {
        bestKey = key
        bestIndex = index
      }
    }
    // No API match at all: the survivors kept their own DEFAULT flags, and the CDN's
    // pick beats a guess.
    return bestIndex
  }

  // MARK: - Line surgery

  private static func isAudioMedia(_ line: String) -> Bool {
    attributes(in: line)["TYPE"] == "AUDIO"
  }

  /// Attribute dictionary of an `#EXT-X-MEDIA:` or `#EXT-X-STREAM-INF:` line —
  /// empty for anything else.
  private static func attributes(in line: String) -> [String: String] {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    for prefix in ["#EXT-X-MEDIA:", "#EXT-X-STREAM-INF:"] {
      if trimmed.hasPrefix(prefix) {
        return HLSManifestParser.attributes(in: String(trimmed.dropFirst(prefix.count)))
      }
    }
    return [:]
  }

  private static func replaceAttribute(_ key: String, with value: String, in line: String) -> String {
    if let range = line.range(of: "\(key)=\"[^\"]*\"", options: .regularExpression) {
      return line.replacingCharacters(in: range, with: "\(key)=\"\(value)\"")
    }
    return line
  }

  static func replaceName(in line: String, with name: String) -> String {
    let escaped = name
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    if let range = line.range(of: #"NAME="[^"]*""#, options: .regularExpression) {
      return line.replacingCharacters(in: range, with: "NAME=\"\(escaped)\"")
    }
    if let typeRange = line.range(of: "TYPE=AUDIO") {
      var out = line
      out.insert(contentsOf: ",NAME=\"\(escaped)\"", at: typeRange.upperBound)
      return out
    }
    return line + ",NAME=\"\(escaped)\""
  }

  static func setDefault(_ line: String, isDefault: Bool) -> String {
    let value = isDefault ? "YES" : "NO"
    if let range = line.range(of: #"DEFAULT=(YES|NO)"#, options: .regularExpression) {
      return line.replacingCharacters(in: range, with: "DEFAULT=\(value)")
    }
    return line + ",DEFAULT=\(value)"
  }

  private static func absolutize(_ lines: [String], baseURL: URL) -> [String] {
    var previousWasStreamInf = false
    return lines.map { line in
      defer {
        previousWasStreamInf = line.trimmingCharacters(in: .whitespaces).hasPrefix("#EXT-X-STREAM-INF:")
      }

      if previousWasStreamInf, !line.isEmpty, !line.hasPrefix("#") {
        return absoluteURL(line, base: baseURL)
      }
      if line.contains("URI=\"") {
        return replaceURI(in: line, base: baseURL)
      }
      return line
    }
  }

  private static func replaceURI(in line: String, base: URL) -> String {
    guard let regex = try? NSRegularExpression(pattern: #"URI="([^"]+)""#) else { return line }
    let ns = line as NSString
    guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
          match.numberOfRanges > 1,
          let uriRange = Range(match.range(at: 1), in: line) else { return line }
    let uri = String(line[uriRange])
    return line.replacingCharacters(in: uriRange, with: absoluteURL(uri, base: base))
  }

  private static func absoluteURL(_ string: String, base: URL) -> String {
    if let url = URL(string: string), url.scheme != nil { return url.absoluteString }
    return URL(string: string, relativeTo: base)?.absoluteString ?? string
  }

}

/// Feeds AVPlayer the relabeled master playlist without ever gating playback on it.
///
/// The player is pointed at the master URL with a custom scheme, which routes the
/// request here; the loader fetches the real playlist, relabels the audio names, and
/// answers from memory. Everything inside the playlist is absolute `https`, so all
/// child playlists and segments load straight from the CDN — this delegate sees exactly
/// one request. A payload that can't be rewritten is passed through untouched (worst
/// case the Audio picker shows the CDN's plain names), and a fetch failure fails the
/// player item so the screen shows an error instead of an endless spinner.
final class HLSMasterResourceLoader: NSObject, AVAssetResourceLoaderDelegate {

  static let scheme = "kinopub-hls"

  private let remote: URL
  private let tracks: [AudioTrackInfo]
  private let session: URLSession

  init(remote: URL, tracks: [AudioTrackInfo]) {
    self.remote = remote
    self.tracks = tracks
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 15
    // An overall cap too: a CDN that answers and then trickles never trips the
    // per-request (inactivity) timeout, and the fetch outlives the prepare watchdog.
    configuration.timeoutIntervalForResource = 30
    self.session = URLSession(configuration: configuration)
  }

  /// The master URL with our scheme swapped in, so AVPlayer routes its request here.
  static func maskedURL(for remote: URL) -> URL? {
    var components = URLComponents(url: remote, resolvingAgainstBaseURL: false)
    components?.scheme = scheme
    return components?.url
  }

  func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                      shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
    Task { await serve(loadingRequest) }
    return true
  }

  private func serve(_ request: AVAssetResourceLoadingRequest) async {
    // Both ends are logged: a hung load is otherwise indistinguishable from a slow one
    // in the diagnostics log — the prepare watchdog fires with no trace of where it stopped.
    Logger.app.debug("HLS master fetch started: \(self.remote.lastPathComponent)")
    do {
      let (data, response) = try await session.data(from: remote)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        throw URLError(.badServerResponse)
      }
      let body = relabeledIfPossible(data)
      request.contentInformationRequest?.contentType = "public.m3u8-playlist"
      request.contentInformationRequest?.contentLength = Int64(body.count)
      request.contentInformationRequest?.isByteRangeAccessSupported = false
      request.dataRequest?.respond(with: body)
      request.finishLoading()
      Logger.app.debug("HLS master served: \(body.count) bytes")
    } catch {
      Logger.app.error("HLS master fetch failed, failing the item: \(error.localizedDescription)")
      request.finishLoading(with: error)
    }
  }

  private func relabeledIfPossible(_ data: Data) -> Data {
    // No API tracks is not a pass-through: the per-quality group collapse below is
    // what keeps the system Audio picker from listing every track three times.
    guard let text = String(data: data, encoding: .utf8),
          text.contains("#EXTM3U") else { return data }
    return Data(HLSAudioLabeler.rewrite(text, baseURL: remote, tracks: tracks).utf8)
  }
}
