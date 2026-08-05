#if os(tvOS)
//
//  TVUIKitRemoteImage.swift
//  KinoPubUI
//
//  Lightweight UIImage load via shared URLCache — same cache plane as system
//  AsyncImage on tvOS 27, without pulling Nuke into the app target.
//

import UIKit

public enum TVUIKitRemoteImage {
  public static func load(url: URL?) async -> UIImage? {
    guard let url else { return nil }
    var request = URLRequest(url: url)
    request.cachePolicy = .returnCacheDataElseLoad
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        return nil
      }
      return UIImage(data: data)
    } catch {
      return nil
    }
  }
}
#endif
