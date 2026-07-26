import Foundation

public enum TMDBIDFormatter {
  /// Formats a numeric IMDb id from kino.pub into the `tt…` form TMDB expects.
  /// Pads to at least 7 digits (`42` → `tt0000042`); longer ids are left as-is.
  public static func imdbString(from numericID: Int) -> String {
    let raw = String(numericID)
    if raw.count >= 7 {
      return "tt\(raw)"
    }
    return "tt" + String(format: "%07d", numericID)
  }
}
