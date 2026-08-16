//
//  CachedRemoteImage.swift
//  KinoPubUI
//
//  Shared artwork atom: the `Artwork` pipeline, distinct empty / failure / success
//  states, and a short fade-in. No eternal gray placeholder wash.
//

import SwiftUI

/// The common artwork configuration: one content mode, distinct placeholder and failure,
/// on the shared `Artwork` pipeline — decoded-image memory cache, one disk entry per URL,
/// in-flight coalescing. Prefer it over `ArtworkImage` unless the states need different
/// geometry.
///
/// This used to be `AsyncImage`, which caches bytes only and, on a 404, commonly stays
/// in `.empty` forever instead of reporting a failure. Both are why `Artwork` exists.
///
/// Keeps the last successful frame when `url` changes so a metadata refresh does
/// not flash the placeholder over art that was already visible.
public struct CachedRemoteImage<Placeholder: View, Failure: View>: View {
  private let url: URL?
  private let contentMode: ContentMode
  private let placeholder: () -> Placeholder
  private let failure: () -> Failure
  @State private var sticky: Image?

  public init(
    url: URL?,
    contentMode: ContentMode = .fill,
    @ViewBuilder placeholder: @escaping () -> Placeholder,
    @ViewBuilder failure: @escaping () -> Failure
  ) {
    self.url = url
    self.contentMode = contentMode
    self.placeholder = placeholder
    self.failure = failure
  }

  public var body: some View {
    ArtworkImage(
      url: url,
      transaction: Transaction(animation: .easeOut(duration: 0.25))
    ) { phase in
      switch phase {
      case .success(let image):
        resized(image)
          .transition(.opacity)
          .task(id: url) { sticky = image }
      case .failure:
        if let sticky { resized(sticky) } else { failure() }
      case .empty:
        if let sticky { resized(sticky) } else { placeholder() }
      }
    }
    .onChange(of: url) { _, newURL in
      if newURL == nil { sticky = nil }
    }
  }

  private func resized(_ image: Image) -> some View {
    image
      .resizable()
      .aspectRatio(contentMode: contentMode)
  }
}

public extension CachedRemoteImage where Placeholder == Color, Failure == Color {
  /// Clear while loading or after failure — never a permanent gray plate.
  init(url: URL?, contentMode: ContentMode = .fill) {
    self.init(
      url: url,
      contentMode: contentMode,
      placeholder: { Color.clear },
      failure: { Color.clear }
    )
  }
}

/// Quiet loading cue for contained artwork (banners, posters). Appears only after
/// a short delay so a warm cache never flashes a spinner. Shows the title when the
/// call site already has it (matches Apple TV / Music holding a static identity
/// placeholder instead of a spinner); otherwise falls back to a neutral glyph.
public struct RemoteImageLoadingCue: View {
  private let title: String?
  private let delay: Duration
  @State private var isVisible = false

  public init(title: String? = nil, delay: Duration = .milliseconds(350)) {
    self.title = title
    self.delay = delay
  }

  public var body: some View {
    Group {
      if let title, !title.isEmpty {
        Text(title)
          .font(.caption)
          .fontWeight(.medium)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .padding(.horizontal, 16)
      } else {
        Image(systemName: "film")
          .font(.title2)
      }
    }
    .foregroundStyle(.white)
    .opacity(isVisible ? 0.55 : 0)
    .animation(.easeOut(duration: 0.2), value: isVisible)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .task {
      try? await Task.sleep(for: delay)
      guard !Task.isCancelled else { return }
      isVisible = true
    }
  }
}

#Preview("Loading cue") {
  HStack(spacing: 16) {
    ZStack {
      Color.black.opacity(0.4)
      RemoteImageLoadingCue(delay: .milliseconds(50))
    }
    .frame(width: 200, height: 160)

    ZStack {
      Color.black.opacity(0.4)
      RemoteImageLoadingCue(title: "Стражи Галактики. Часть 3", delay: .milliseconds(50))
    }
    .frame(width: 200, height: 160)
  }
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Cached remote image") {
  CachedRemoteImage(
    url: URL(string: "https://m.staticpop.net/poster/item/big/581.jpg"),
    contentMode: .fill,
    placeholder: {
      ZStack {
        Color.black.opacity(0.35)
        RemoteImageLoadingCue()
      }
    },
    failure: { Color.red.opacity(0.3) }
  )
  .frame(width: 200, height: 300)
  .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
