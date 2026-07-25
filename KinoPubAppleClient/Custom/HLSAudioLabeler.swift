//
//  HLSAudioLabeler.swift
//  KinoPubAppleClient
//
//  Rewrites a kino.pub HLS master so the system Audio picker shows useful names.
//
//  AVKit reads `NAME=` off `#EXT-X-MEDIA:TYPE=AUDIO` — kino.pub puts only the
//  language there ("Russian", "Russian", "Russian"). The API already knows the
//  dub kind and studio; we stamp those into NAME before handing the playlist to
//  AVPlayer. Child playlist URIs are made absolute so a file:// master still
//  resolves against the CDN.
//

import Foundation
import KinoPubBackend

enum HLSAudioLabeler {

  /// Fetches `remote`, rewrites AUDIO names from `tracks`, writes a temp master,
  /// and returns its file URL.
  static func labeledMasterURL(from remote: URL,
                               tracks: [AudioTrackInfo]) async throws -> URL {
    let (data, response) = try await URLSession.shared.data(from: remote)
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw LabelError.fetchFailed(http.statusCode)
    }
    guard let text = String(data: data, encoding: .utf8), text.contains("#EXTM3U") else {
      throw LabelError.notAPlaylist
    }

    let rewritten = rewrite(text, baseURL: remote, tracks: tracks)
    guard rewritten.contains("NAME=\"") else { throw LabelError.nothingToRewrite }

    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("kinopub-hls", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("\(UUID().uuidString).m3u8")
    try rewritten.write(to: file, atomically: true, encoding: .utf8)
    return file
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

  enum LabelError: Error {
    case fetchFailed(Int)
    case notAPlaylist
    case nothingToRewrite
  }
}
