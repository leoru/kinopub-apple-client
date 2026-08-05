//
//  LandscapePlayChromeVariants.swift
//  KinoPubUI
//
//  Axis: play-primary landscape chrome. Shipping default is `.glass`.
//  Delete this file once one treatment is locked.
//

#if DEBUG
import SwiftUI

#Preview("Landscape play chrome") {
  VariantGallery("Continue Watching play", axis: "center chrome material / size") {
    Variant("glass (shipping)") {
      sample(style: .glass)
    }
    Variant("translucent plate") {
      sample(style: .translucent)
    }
    Variant("glass large") {
      sample(style: .glassLarge)
    }
  }
  .preferredColorScheme(.dark)
}

@MainActor
private func sample(style: LandscapePlayChromeStyle) -> some View {
  MediaCardView(
    card: MediaCard(
      id: 581,
      posterURL: "https://m.staticpop.net/poster/item/big/581.jpg",
      title: "Стражи Галактики",
      progress: 0.42,
      landscapeImageURL: "https://m.staticpop.net/poster/item/wide/581.jpg",
      overlayLabel: "S2, E5 · 42 min",
      isSeries: true,
      primaryAction: .play
    ),
    caption: .always,
    playChromeStyle: style,
    forcePlayChrome: true
  )
  .frame(width: 320)
}
#endif
