//
//  FallbackRemoteImage.swift
//  KinoPubUI
//
//  Tries URLs in order (wide → big → poster). Uses URLSession so HTTP 404
//  advances to the next candidate — AsyncImage often stays in `.empty` forever
//  on a missing CDN object instead of reporting `.failure`.
//

import SwiftUI
import OSLog
#if os(macOS)
import AppKit
#else
import UIKit
#endif

private let artLog = Logger(subsystem: "com.soda.kinopub", category: "Artwork")

/// Loads the first URL that returns image bytes. Used by Home banners where
/// catalogue `/wide/` derivations often 404 while `big` still paints.
public struct FallbackRemoteImage: View {
  private let urls: [URL]
  private let contentMode: ContentMode
  @State private var image: Image?
  @State private var loading = true

  public init(urls: [URL], contentMode: ContentMode = .fill) {
    self.urls = urls
    self.contentMode = contentMode
  }

  public var body: some View {
    Group {
      if let image {
        image
          .resizable()
          .aspectRatio(contentMode: contentMode)
          .transition(.opacity)
      } else if loading {
        Color.black.opacity(0.25)
          .overlay { RemoteImageLoadingCue() }
      } else {
        Color.black.opacity(0.4)
      }
    }
    .task(id: urls.map(\.absoluteString).joined(separator: "|")) {
      await load()
    }
  }

  @MainActor
  private func load() async {
    image = nil
    loading = true
    defer { loading = false }

    guard !urls.isEmpty else {
      artLog.debug("FallbackRemoteImage: no candidate URLs")
      return
    }

    for url in urls {
      if Task.isCancelled { return }
      do {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
          artLog.debug("art HTTP \(http.statusCode) \(url.absoluteString, privacy: .public)")
          continue
        }
        #if os(macOS)
        guard let nsImage = NSImage(data: data) else {
          artLog.debug("art decode fail \(url.absoluteString, privacy: .public)")
          continue
        }
        image = Image(nsImage: nsImage)
        #else
        guard let uiImage = UIImage(data: data) else {
          artLog.debug("art decode fail \(url.absoluteString, privacy: .public)")
          continue
        }
        image = Image(uiImage: uiImage)
        #endif
        artLog.debug("art OK \(url.absoluteString, privacy: .public)")
        #if DEBUG
        print("[Artwork] OK \(url.absoluteString)")
        #endif
        return
      } catch {
        artLog.debug("art error \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        #if DEBUG
        print("[Artwork] fail \(url.absoluteString) — \(error.localizedDescription)")
        #endif
      }
    }

    artLog.debug("FallbackRemoteImage: all candidates failed (\(urls.count))")
    #if DEBUG
    print("[Artwork] exhausted \(urls.count) candidates")
    #endif
  }
}
