//
//  ArtworkImage.swift
//  KinoPubUI
//
//  The artwork primitive: `AsyncImage`'s shape — a phase you switch on — running on the
//  shared `Artwork` pipeline instead of `URLCache`. Everything else in the stack is this
//  plus a configuration: `CachedRemoteImage` is the sticky, placeholder/failure form,
//  `FallbackRemoteImage` the try-these-in-order form.
//
//  It exists because a page's states are not always the same shape. A title logo that
//  fails becomes a text block with its own geometry, and the success image is framed to
//  the logo box — a fixed content mode cannot say that. Reach for `CachedRemoteImage`
//  first; take this when the states genuinely differ.
//

import SwiftUI
import NukeUI

/// Mirrors `AsyncImagePhase` so a call site converts by changing the type name.
public enum ArtworkPhase {
  case empty
  case success(Image)
  case failure(any Error)

  public var image: Image? {
    guard case .success(let image) = self else { return nil }
    return image
  }

  public var error: (any Error)? {
    guard case .failure(let error) = self else { return nil }
    return error
  }
}

public struct ArtworkImage<Content: View>: View {
  private let url: URL?
  private let animation: Animation?
  private let content: (ArtworkPhase) -> Content

  public init(
    url: URL?,
    transaction: Transaction = Transaction(),
    @ViewBuilder content: @escaping (ArtworkPhase) -> Content
  ) {
    self.url = url
    self.animation = transaction.animation
    self.content = content
  }

  public var body: some View {
    LazyImage(request: url.map { Artwork.request($0) }) { state in
      content(phase(of: state))
    }
    .pipeline(Artwork.pipeline)
    .transaction { $0.animation = animation }
  }

  private func phase(of state: LazyImageState) -> ArtworkPhase {
    if let loaded = state.imageContainer?.image { return .success(Image(platformImage: loaded)) }
    if let error = state.error { return .failure(error) }
    return .empty
  }
}
