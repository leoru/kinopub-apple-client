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
  /// "2 h 11 min" style, for the metadata line. `totalFormatted` is positional
  /// ("2:11:58") and only sets `allowedUnits` on iOS, so it reads badly elsewhere.
  var hoursMinutesFormatted: String {
    Self.hoursMinutes(seconds: Int(total))
  }

  /// Seconds → "1 h 48 min" (or "48 min" under an hour), shared by anything showing a
  /// runtime — a bare "108 min" reads badly for a feature.
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

  /// Compact runtime for tight chrome — "2h 35m", "2h", "39m".
  static func compactHoursMinutes(seconds: Int) -> String {
    let totalMinutes = Int((Double(seconds) / 60).rounded())
    guard totalMinutes > 0 else { return "" }
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 {
      return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }
    return "\(minutes)m"
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
