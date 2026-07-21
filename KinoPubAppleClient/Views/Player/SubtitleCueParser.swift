//
//  SubtitleCueParser.swift
//  KinoPubAppleClient
//

import Foundation

struct SubtitleCue: Identifiable, Equatable, Hashable {
  let id: Int
  let start: TimeInterval
  let end: TimeInterval
  let text: String

  var displayText: String {
    text
      .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
      .replacingOccurrences(of: "\\{\\\\[^}]+\\}", with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var words: [String] {
    displayText
      .components(separatedBy: .whitespacesAndNewlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}

enum SubtitleCueParser {
  static func parse(_ content: String, shiftMilliseconds: Int = 0) -> [SubtitleCue] {
    let normalized = content
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    let blocks = normalized.components(separatedBy: "\n\n")
    let shift = TimeInterval(shiftMilliseconds) / 1000.0

    var cues: [SubtitleCue] = []
    var index = 0

    for block in blocks {
      let lines = block
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
      guard lines.count >= 2 else { continue }

      let timingLine: String
      let textLines: [String]
      if lines[0].contains("-->") {
        timingLine = lines[0]
        textLines = Array(lines.dropFirst())
      } else if lines.count >= 3, lines[1].contains("-->") {
        timingLine = lines[1]
        textLines = Array(lines.dropFirst(2))
      } else {
        continue
      }

      guard let timing = parseTiming(timingLine) else { continue }
      let text = textLines.joined(separator: "\n")
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

      cues.append(SubtitleCue(
        id: index,
        start: timing.start + shift,
        end: timing.end + shift,
        text: text
      ))
      index += 1
    }

    return cues
  }

  static func cue(at time: TimeInterval, in cues: [SubtitleCue]) -> SubtitleCue? {
    cues.first { time >= $0.start && time <= $0.end }
  }

  private static func parseTiming(_ line: String) -> (start: TimeInterval, end: TimeInterval)? {
    let parts = line.components(separatedBy: "-->")
    guard parts.count == 2 else { return nil }
    let startRaw = parts[0].trimmingCharacters(in: .whitespaces)
    let endRaw = parts[1]
      .trimmingCharacters(in: .whitespaces)
      .components(separatedBy: .whitespaces)
      .first ?? ""
    guard let start = parseTimestamp(startRaw), let end = parseTimestamp(endRaw) else { return nil }
    return (start, end)
  }

  private static func parseTimestamp(_ value: String) -> TimeInterval? {
    // Supports 00:01:02,345 and 00:01:02.345 and 01:02,345
    let cleaned = value
      .replacingOccurrences(of: ",", with: ".")
      .trimmingCharacters(in: .whitespaces)
    let pieces = cleaned.split(separator: ":").map(String.init)
    guard pieces.count == 2 || pieces.count == 3 else { return nil }

    let hours: TimeInterval
    let minutes: TimeInterval
    let seconds: TimeInterval

    if pieces.count == 3 {
      guard let h = Double(pieces[0]), let m = Double(pieces[1]), let s = Double(pieces[2]) else { return nil }
      hours = h
      minutes = m
      seconds = s
    } else {
      guard let m = Double(pieces[0]), let s = Double(pieces[1]) else { return nil }
      hours = 0
      minutes = m
      seconds = s
    }

    return hours * 3600 + minutes * 60 + seconds
  }
}
