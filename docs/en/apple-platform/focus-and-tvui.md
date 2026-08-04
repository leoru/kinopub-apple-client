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

Public tvOS-only framework, currently **unused in this repo**. "Lockup" in our SwiftUI code means
`.buttonStyle(.borderless)` + `.hoverEffect` — that is a different thing from `TVLockupView`.
Verified against `AppleTVOS27.0.sdk/System/Library/Frameworks/TVUIKit.framework/Headers`.

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
"one focus owner per zone" rule above. Do **not** read this table as a mandate to port the rails.

Where it is genuinely worth the bridge:

- **`TVCollectionViewFullScreenLayout` for an autoplay hero.** `didCenterCellAtIndexPath:` is a
  system-provided "this card settled in the centre" hook — exactly the trigger a Netflix-style
  autoplaying hero needs, without hand-rolling centre detection, debounce, and fast-scroll
  cancellation. **Needs validation** before committing.
- Our SwiftUI cards on `.borderless` + `.hoverEffect(.highlight)` already get system lift, specular,
  and tilt. Replacing them with TVUIKit is not an automatic upgrade — argue it per case.

## Project decisions

- Poster cards: native borderless lockup + hover highlight; captions react via `\.isFocused`.
- Rows screens hand focus to the first banner or shelf card, not the tab bar.
- No inert reserved space above rows (old 560pt featured-preview spacer is gone).
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
