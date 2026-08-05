//
//  HLSAudioLabeler.swift
//  KinoPubAppleClient
//
//  Rewrites a kino.pub HLS master so audio renditions carry useful names.
//
//  kino.pub puts only the language in `NAME=` on `#EXT-X-MEDIA:TYPE=AUDIO`
//  ("Russian", "Russian", "Russian"). The API already knows the dub kind and
//  studio, so we stamp those in. What we write arrives as the selection option's
//  common-metadata title — read it with `AVMediaSelectionOption.kinopubTrackName`,
//  not `displayName`, which discards it (see that property's note). Child
//  playlist URIs are made absolute because the rewritten master is served from
//  memory, not from the CDN.
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

  /// Pure rewrite for tests: absolute-izes relative URIs and replaces AUDIO `NAME`s.
  static func rewrite(_ playlist: String,
                      baseURL: URL,
                      tracks: [AudioTrackInfo],
                      preferredLanguages: [String] = Locale.preferredLanguages) -> String {
    let lines = playlist.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let audioIndices = lines.indices.filter { isAudioMedia(lines[$0]) }
    guard !audioIndices.isEmpty, !tracks.isEmpty else {
      return absolutize(lines, baseURL: baseURL).joined(separator: "\n")
    }

    let languages = audioIndices.map { language(in: lines[$0]) }
    let labels = AudioTracks.labelsForHLSRenditions(languages: languages, tracks: tracks)
    let defaultIndex = bestAudioIndex(languages: languages, tracks: tracks,
                                      preferredLanguages: preferredLanguages)

    var out = lines
    for (offset, lineIndex) in audioIndices.enumerated() {
      var line = replaceName(in: out[lineIndex], with: labels[offset])
      line = setDefault(line, isDefault: offset == defaultIndex)
      out[lineIndex] = line
    }
    return absolutize(out, baseURL: baseURL).joined(separator: "\n")
  }

  // MARK: - DEFAULT pick

  private static func bestAudioIndex(languages: [String?],
                                     tracks: [AudioTrackInfo],
                                     preferredLanguages: [String]) -> Int {
    var queues: [String: [AudioTrackInfo]] = [:]
    for track in tracks {
      queues[SubtitleTracks.languageKey(track.lang), default: []].append(track)
    }
    let matched: [AudioTrackInfo?] = languages.map { lang in
      let key = SubtitleTracks.languageKey(lang ?? "")
      guard var queue = queues[key], !queue.isEmpty else { return nil }
      let track = queue.removeFirst()
      queues[key] = queue
      return track
    }

    var bestIndex = 0
    var bestKey: AudioTracks.SortKey?
    for (index, track) in matched.enumerated() {
      guard let track else { continue }
      let key = AudioTracks.sortKey(for: track, preferredLanguages: preferredLanguages)
      if bestKey == nil || key < bestKey! {
        bestKey = key
        bestIndex = index
      }
    }
    return bestIndex
  }

  // MARK: - Line surgery

  private static func isAudioMedia(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("#EXT-X-MEDIA:") else { return false }
    let attrs = HLSManifestParser.attributes(in: String(trimmed.dropFirst("#EXT-X-MEDIA:".count)))
    return attrs["TYPE"] == "AUDIO"
  }

  private static func language(in line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("#EXT-X-MEDIA:") else { return nil }
    let attrs = HLSManifestParser.attributes(in: String(trimmed.dropFirst("#EXT-X-MEDIA:".count)))
    return attrs["LANGUAGE"]
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
    } catch {
      Logger.app.error("HLS master fetch failed, failing the item: \(error.localizedDescription)")
      request.finishLoading(with: error)
    }
  }

  private func relabeledIfPossible(_ data: Data) -> Data {
    guard !tracks.isEmpty,
          let text = String(data: data, encoding: .utf8),
          text.contains("#EXTM3U") else { return data }
    return Data(HLSAudioLabeler.rewrite(text, baseURL: remote, tracks: tracks).utf8)
  }
}
