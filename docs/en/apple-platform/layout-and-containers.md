# Layout and containers

## Evergreen

- Prefer system containers: `HStack` / `VStack` / `ZStack`, then `LazyHStack` in `ScrollView` for
  shelves, `LazyVGrid` / `LazyHGrid` for galleries, `List` / `Form` when you want system chrome and
  edit gestures. Start eager; switch to lazy only when profiling shows benefit.
  ([Picking container views](https://developer.apple.com/documentation/swiftui/picking-container-views-for-your-content))
- Adaptive shelves: `containerRelativeFrame(.horizontal, count:spacing:)` (commonly ~6 columns for
  posters; fewer under accessibility Dynamic Type). This replaces hard-coded card widths.
- Also useful on baseline 16–17 already: `ViewThatFits`, `contentMargins`, `safeAreaPadding`,
  `scrollTargetBehavior` / `scrollTargetLayout`, custom `Layout`.
- **tvOS 27** enables Large Content / Dynamic Type systemically. Hard-coded font sizes and fixed
  frames will clip — WWDC 2026 session *Prepare your tvOS apps for Dynamic Type*.

## Project decisions

- Poster and landscape cards share one sizing model via `ShelfMetrics` / proportional columns (D2).
- Home banner: contained 16:9 cards (~2 columns on wide), full width on phone; view-aligned snap.
- Detail: one vertical `ScrollView` (hero + content). The old offset slideshow / focus-bridge detail
  model is **superseded**.

## Pitfalls

- Fixed `frame(width:height:)` forests in cards break Dynamic Type and multiplatform scaling.
- Inert spacers above the first focusable row steal Up and trap focus in the tab bar.
- Do not invent a second grid library when `LazyVGrid` + `containerRelativeFrame` suffice; evaluate
  third-party grids only with a measured gap.
