//
//  FallbackRemoteImage.swift
//  KinoPubUI
//
//  Tries URLs in order (wide → big → poster) and keeps the first that returns image
//  bytes. The fallback chain is ours — no image library models "try these in order" —
//  but each attempt goes through the shared `Artwork` pipeline, so a candidate that
//  already failed or already loaded is answered from cache instead of refetched.
//

import SwiftUI
import OSLog
import Nuke

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
        let loaded = try await Artwork.pipeline.image(for: Artwork.request(url))
        image = Image(platformImage: loaded)
        artLog.debug("art OK \(url.absoluteString, privacy: .public)")
        #if DEBUG
        print("[Artwork] OK \(url.absoluteString)")
        #endif
        return
      } catch {
        // A 404 on a `/wide/` derivation is the normal case this view exists for, not
        // an incident — the next candidate usually paints.
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
