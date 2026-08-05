# Focus and TVUIKit

## Evergreen

- True layered parallax needs **layered images** (HIG). Flat posters get lift, scale, specular, and
  tilt toward the touch surface — not multi-layer parallax.
- System focus highlight attaches to the first `Image` in a button label by default. `AsyncImage`
  alone often **does not** get it — add explicit `.hoverEffect(.highlight)` (and usually
  `.buttonStyle(.borderless)` for poster lockups).
- One focus owner per interactive zone. Prefer layout-driven focus (`focusSection`, `defaultFocus`)
  over hybrid bridges. Avoid `.defaultFocus(..., .userInitiated)` unless you understand the reset.
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
