//
//  ActorImageProvider.swift
//  KinoPubAppleClient
//
//  kino.pub-adjacent actor/director portraits from a CDN keyed by the MD5 of the
//  (Russian) name — the scheme the kpapp.link web app uses:
//    https://m.pushbr.com/actors/<md5(name)>.jpg
//  Ported from dungeon-master-xx/kinopub-apple-client. Missing photos return HTTP
//  403; callers fall back to a placeholder via the async image loader.
//
//  Prefer TMDB photos when `KinoPubMetadata` already resolved one; use this as a
//  no-key fallback for names that never hit TMDB.
//

import Foundation
import CryptoKit

enum ActorImageProvider {
  /// Portrait URL for a cast/crew member by their exact name string (as returned by kino.pub).
  static func photoURL(for name: String) -> URL? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let digest = Insecure.MD5.hash(data: Data(trimmed.utf8))
    let hex = digest.map { String(format: "%02x", $0) }.joined()
    return URL(string: "https://m.pushbr.com/actors/\(hex).jpg")
  }

  static func photoURLString(for name: String) -> String? {
    photoURL(for: name)?.absoluteString
  }
}
