# Focus and TVUIKit

## Evergreen

- True layered parallax needs **layered images** (HIG). Flat posters get lift, scale, specular, and
  tilt toward the touch surface — not multi-layer parallax.
- System focus highlight attaches to the first `Image` in a button label by default. `AsyncImage`
  alone often **does not** get it — add explicit `.hoverEffect(.highlight)` (and usually
  `.buttonStyle(.borderless)` for poster lockups).
- **For a focusable *container* on tvOS, reach for `.buttonStyle(.card)` first and write no focus
  code at all.** Apple's own `DestinationVideo` sample does exactly
  `var buttonStyle: some PrimitiveButtonStyle { #if os(tvOS) .card #else .plain #endif }` on every
  card in the app, applies it once to the enclosing stack, and fences `.hoverEffect()` to
  iOS/visionOS. Focus scale, highlight, lift and parallax are system-owned. Everything focusable
  there is a `Button` or `NavigationLink` — including things that are really just focus stops.
- **Corollary, learned the hard way 2026-08-09 (twice): `.hoverEffect(.highlight)` is for controls
  whose label *is* the image.** On a control labelled `icon + text` (rating tiles, vote pills) it
  does the literal thing — scales and shadows the icon alone while the container sits still. The
  hand-rolled `scaleEffect` + `brightness` replacement that followed was functionally right but read
  as non-native; `.card` is the answer, and it makes both the custom style and the row's manual
  focus padding unnecessary. Do not stack `hoverEffect` / `scaleEffect` / `isFocused` branches on
  top of `.card`.
- One focus owner per interactive zone. Prefer layout-driven focus (`focusSection`, `defaultFocus`)
  over hybrid bridges. Avoid `.defaultFocus(..., .userInitiated)` unless you understand the reset.
- **Never bind two sibling views to the same `@FocusState` equals-value.** `.focused($x, equals:
  .same)` on multiple views is ambiguous — the engine can't resolve which one is actually focused.
  Found on-device 2026-08-09 costing a real regression: six `MediaItemHeroView` buttons shared one
  case (`heroOther`), and focus froze dead on Play — not just "couldn't reach that group," genuinely
  stuck, Right and Down both no-ops, on movies with full metadata as much as sparse ones. Menu even
  closed the app instead of popping, because the confused focus state broke the NavigationStack's
  back-context too. One case per focusable view. If it's flagged as a "someday" cleanup item
  somewhere, fix it on sight instead — this one sat in a checklist and cost a misdiagnosed detour
  before anyone traced it. See [detail-page-choreography](../plans/detail-page-choreography.md).
- Simulator focus/remote is provisional; Device Hub hosts the window — there is no separate
  Simulator.app on current Xcode. Escape ≠ Menu.

## TVUIKit inventory

Public tvOS-only framework. "Lockup" in our SwiftUI code still means
`.buttonStyle(.borderless)` + `.hoverEffect` — that is a different thing from `TVLockupView`.
Verified against `AppleTVOS27.0.sdk/System/Library/Frameworks/TVUIKit.framework/Headers`.

**In use (shelves + grids, gated):** `TVPosterView` / `TVCardView` inside one shared
`TVUIKitMediaCollection` (horizontal shelf or vertical grid — same cell, same
`ShelfMetrics` sizing) under `FeatureFlags.tvUIKitPosters` /
`EnvironmentValues.usesTVUIKitPosters`
([`KinoPubUI/Components/TVUIKit/`](../../../Packages/KinoPubUI/Sources/KinoPubUI/Components/TVUIKit/)).
Rivulet pattern: caption nil on `TVPosterView`, overlays as a sibling of the image view with
focus-scale sync + stale-appearance reset. Flag stays **off** until Device Hub focus validation.
A Home shelf is the same poster grid scrolled sideways — not a second card component.

| Type | Availability | What it gives |
| --- | --- | --- |
| `TVPosterView` | tvOS 12 | Image + title + subtitle. Computes the **optimal `focusSizeIncrease` from the image**; overriding it has no visible effect |
| `TVLockupView` (+ `TVLockupViewComponent`) | tvOS 12 | Header / footer that move on focus; `updateAppearanceForLockupViewState:` pushes `.focused` / `.highlighted` into subviews |
| `TVCardView` | tvOS 12 | Floating card lockup; contents respond to focus as one unit |
| `TVCaptionButtonView` | tvOS 12 | Button + caption, knock-out effect, `motionDirection` |
| `TVMediaItemContentConfiguration` | tvOS 15 | The TV-app media cell: image, text, secondaryText, **`playbackProgress`**, **`badgeText` / `badgeProperties`** (incl. `liveContentBadgeProperties`), `overlayView`, `focusedFrameGuide`, `+wideCellConfiguration` |
| `TVCollectionViewFullScreenLayout` | tvOS 13 | Full-screen paging layout: `parallaxFactor`, `maskAmount`, `contentBleed`, `cornerRadius`, and `willCenterCellAtIndexPath:` / `didCenterCellAtIndexPath:` delegate callbacks |
| `TVMonogramView`, `TVDigitEntryViewController` | tvOS 12 | Person monogram; PIN entry |

Cost, stated honestly: all of it is UIKit. `TVMediaItemContentConfiguration` implies a
`UICollectionView` rail rather than a SwiftUI `LazyHStack`, and any bridge risks the
"one focus owner per zone" rule above. Do **not** read this table as a mandate to port every rail.

Where it is genuinely worth the bridge:

- **Poster shelves and poster grids** — one `TVUIKitMediaCollection` + `TVUIKitPosterCell`
  (horizontal or vertical). Shipping path behind the flag above.
- **`TVCollectionViewFullScreenLayout` for an autoplay hero.** `didCenterCellAtIndexPath:` is a
  system-provided "this card settled in the centre" hook — exactly the trigger a Netflix-style
  autoplaying hero needs, without hand-rolling centre detection, debounce, and fast-scroll
  cancellation. **Needs validation** before committing.
- SwiftUI `.borderless` + `.hoverEffect(.highlight)` remains the fallback (and the path on
  iOS/macOS). Detail / person rails that are not the shared poster atom stay SwiftUI until ported.

## Project decisions

- **tvOS posters:** one atom — `TVPosterView` cell in `TVUIKitMediaCollection` — for Home shelves
  and Movies/Series/Search/History/Watchlist grids when `FeatureFlags.tvUIKitPosters` is on.
  Same `ShelfMetrics` sizing either orientation. SwiftUI `MediaCardView` is the fallback / other
  platforms.
- Rows screens hand focus to the first banner or shelf card, not the tab bar.
- No inert reserved space above rows (old 560pt featured-preview spacer is gone).
- Detail ambient muted trailer is **off on tvOS** (still + scrims + blurred poster wash). Trailer
  button / real player unchanged. Ambient trailer may return with a dedicated hero pass.
- Detail below-fold wash: section focus forces full wash; scroll offset scrubs
  `.regularMaterial` over the poster wash and fades hero chrome faster (`1 - min(1, p·2.6)`).
  No vertical `.viewAligned` on the detail `ScrollView` (it fought section focus).
- **A screen must never be able to lose its way out.** Three rules, from a one-way trap observed in
  the reference app (empty below-fold + hero already made non-focusable = no Up, no exit):
  1. Do not enter a "scrolled past the hero" state until at least one focusable row exists below.
  2. Do not drop the hero's focusability until focus has actually landed below it. Fading chrome is
     not the same as removing it — `MediaItemHeroView.chromeAlpha` keeps a 0.35 floor precisely so
     Play/More stay in the focus graph.
  3. Empty and error states are **focusable sections with a Retry control**, never an empty list.
     An empty list is a focus dead end on tvOS, not just a blank area.
- Focus moves inside a hero must not scroll the page. Hero chrome belongs **outside** the scrolling
  container; when it sits inside one, every focus change triggers scroll-to-visible and the page
  jitters as the user moves between Play / Watched / More. See
  [detail-page-choreography](../plans/detail-page-choreography.md).
- Top Shelf is a **later platform-completeness** item — before advanced subtitles, after core catalog
  / shell work. **Needs validation** on entitlement / extension packaging when implemented.

## Superseded

- Hand-rolled `SiriRemoteTilt` / Game Controller joystick fake parallax.

**Reopened:** the passive focus-marquee / autoplaying Home hero was listed here as superseded. The
user has since said the product is heading that way. Treat it as an open design direction, not a
rejected one — see `TVCollectionViewFullScreenLayout` above.

## Pitfalls

- `.buttonStyle(.plain)` commonly kills visible focus.
- Claiming focus bugs fixed from previews or headless simulator alone.
