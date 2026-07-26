//
//  Duration.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Duration: Codable, Hashable {
  public let average: Double
  public let total: TimeInterval
}

public extension Duration {
  /// Legacy long form used by older chrome — prefer `compact` for new UI.
  var hoursMinutesFormatted: String {
    Self.hoursMinutes(seconds: Int(total))
  }

  /// Seconds → "1 h 48 min" (or "48 min" under an hour).
  static func hoursMinutes(seconds: Int) -> String {
    let totalMinutes = Int((Double(seconds) / 60).rounded())
    guard totalMinutes > 0 else { return "" }
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 {
      return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h"
    }
    return "\(minutes) min"
  }

  /// Compact runtime used across the app — "2h 35m", "39m", and past a day "1d 12h 4m".
  static func compact(seconds: Int) -> String {
    let totalMinutes = Int((Double(seconds) / 60).rounded())
    guard totalMinutes > 0 else { return "" }
    let days = totalMinutes / (60 * 24)
    let hours = (totalMinutes % (60 * 24)) / 60
    let minutes = totalMinutes % 60
    var parts: [String] = []
    if days > 0 { parts.append("\(days)d") }
    if hours > 0 { parts.append("\(hours)h") }
    if minutes > 0 || parts.isEmpty { parts.append("\(minutes)m") }
    return parts.joined(separator: " ")
  }

  /// Compact with a minutes total in parentheses once the runtime is an hour or more —
  /// `1h 45m (105 min)`. Under an hour stays `39m`.
  static func compactWithMinutes(seconds: Int) -> String {
    let totalMinutes = Int((Double(seconds) / 60).rounded())
    guard totalMinutes > 0 else { return "" }
    let compact = Self.compact(seconds: seconds)
    guard totalMinutes >= 60 else { return compact }
    return "\(compact) (\(totalMinutes) min)"
  }

  /// Alias kept for call sites that still say "hoursMinutes".
  static func compactHoursMinutes(seconds: Int) -> String {
    compact(seconds: seconds)
  }

  var totalFormatted: String {
    let formatter = DateComponentsFormatter()
    #if os(iOS)
    formatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
    #endif
    formatter.unitsStyle = .positional
    return formatter.string(from: self.total) ?? ""
  }
}
