---
name: tvos-surface
description: Building or debugging any tvOS media surface — rails, grids, cells, posters, the detail page, focus behavior, remote input, or anything using TVUIKit / UICollectionView on Apple TV. Use before writing focus code, before adding a tile or a rail, and when focus behaves strangely on device.
---

# tvOS surfaces: cells, rails, focus

On tvOS, media surfaces are **UIKit + TVUIKit**. The focus engine, cell reuse, predictable layout
and memory all live there, and SwiftUI on a heavy TV surface is a leftover to port, not a base.
SwiftUI stays for the shell, settings, forms and one-off chrome.

API facts below are read out of
`AppleTVOS27.0.sdk/System/Library/Frameworks/TVUIKit.framework/Headers`, not from memory.

## Three cells and one collection

Not three cells *preferred* — three cells. A tile assembled by hand out of image views, labels and a
progress bar is a defect even when it looks right, because the system already ships that tile and
ours drifts the moment two screens need it.

| On screen | The cell | What the system already does |
| --- | --- | --- |
| A **person** — anyone with a face and a name | `TVMonogramContentConfiguration.cell()` as the cell's `contentConfiguration` | Draws the circle, focus motion, and localized initials from `personNameComponents` when `image` is nil. A photo goes in `image`; a monogram is the *fallback*, never the intended look for someone we have a portrait of |
| A **wide 16:9 thing** — still, episode, trailer, Continue Watching, genre tile | `TVMediaItemContentConfiguration.wideCell()` | `image`, `text`, `secondaryText`, `playbackProgress`, `badgeText` + `badgeProperties` (incl. live-content), `overlayView`, `focusedFrameGuide`. Every part of an episode tile is a property on this struct |
| A **2:3 poster** | `TVPosterView` (the `TVLockupView` family) | Focus lift, specular, and `focusSizeIncrease` computed from the image. There is **no** poster variant of the media-item configuration — `wideCell()` is the only factory. Do not go looking again |

And the container:

- **Layout comes from `NSCollectionLayoutSection.orthogonalLayoutSectionForMediaItems()`** — the
  system's own rail: item size, gutter, insets, focus room. It replaces hand-tuned `itemSize` /
  `minimumLineSpacing` on a flow layout.
- **One `UICollectionView` per page region, with several sections in it** — not one bridged
  `UIViewControllerRepresentable` per rail stacked in a `VStack`. Separate bridges are separate
  focus owners, separate reload cycles, and separate places for metrics to drift.

Rules that follow:

1. **An episode tile *is* a Continue Watching tile *is* a trailer tile.** Same component, same file;
   only `text` / `secondaryText` / status differ.
2. **The caption lives in the configuration**, under the artwork, in `text` — not a label positioned
   over the image, not gated on focus.
3. **`overlayView` is the only sanctioned place for anything of ours** over the artwork, and it
   stays one view with one look.
4. **Type styling goes through `textProperties` / `secondaryTextProperties`** (`font`, `color`) —
   the only knobs those configurations expose, and therefore the only ones allowed. If tvOS type
   looks worse than the iOS rail, that is a bug in what we set, not a licence to hand-draw the cell.
5. **No custom `didUpdateFocus`, `scaleEffect`, shadow or stale-appearance reset** on a cell with a
   system content configuration. Needing one means the wrong cell is in use.

### One label, clean artwork

- **One text line.** `secondaryText` produced nothing visible on screen, so a second line cost tile
  width and bought nothing. Pack what matters into one caption. The one lead never tried, if it is
  ever wanted back: Apple's sample builds the configuration as
  `wideCell().updatedConfiguration(for: state)`, and we never call that.
- **Nothing large goes on the artwork, and no dates under it** — an announced episode says so in its
  top-corner badge; repeating it below is the same fact twice. Allowed over the image: the badge,
  the progress bar, the duration chip, the watch-status glyph.
- No lockups, no footer views.
- Caption formats differ by surface: `S2 E4 • Episode Name` where a rail spans shows (Continue
  Watching, history), `7. "Episode Name"` inside a season rail where the tab above already names it.

### Two deliberate exceptions, with their trade stated

- **The progress bar is ours, not `playbackProgress`.** The system's only paints on the *focused*
  tile, and "started, not finished" is exactly what an idle rail has to say. `playbackProgress` is
  set to 0 and the bar lives in the overlay. We own a bar; in exchange it is visible when it matters.
- **`badgeText` is a `String`** — which means a glyph *can* ride along (an SF Symbol is a character
  in the SF Symbols font). Do not repeat the claim that the system badge cannot show an icon; if a
  probe shows the glyph does not render, that is an Apple API limitation with evidence, and it still
  is not a reason for a second badge system.

## Sizing and air

Two numbers are decided once, in `ShelfMetrics`, and everything else derives:

- **The card width is pinned, not divided.** `tvCardWidth` / `tvLandscapeCardWidth` are what a tile
  *is*; the container decides how many fit, never how big they are. Dividing the container by a
  column count is what made the same poster a different size in a full-width Home rail and in a grid
  beside a sidebar. The leftover becomes slack, centred in a grid. Width alone cannot classify a
  canvas: 1500pt is both a Mac window wanting eight columns and the tvOS Library grid beside its
  420pt sidebar, still read from a sofa. A narrower TV container gets fewer cards, never smaller ones.
- **Gutters and focus room derive from the growth, not from taste.** A focused tile grows ~10% of
  its own size, half into each neighbour's side of the gap — so a constant gutter reads fine at rest
  and collides on focus, which is exactly what a 20pt gutter under a 290pt poster did.
  `ShelfMetrics.tvGutter(cardWidth:)` and `TVUIKitPosterMetrics.focusGrowthPadding(tileHeight:)` are
  the one rule; no rail, grid or avatar strip gets its own spacing constant.
- **The page margin is `max(design margin, the container's own safe-area inset)`.** A grid already
  sits inside SwiftUI's safe area while the detail page ignores it horizontally and must supply the
  overscan margin itself. A sum double-insets one of them; the larger is right for both and never
  lands content in overscan. Measured through one `onGeometryChange` (`ShelfGeometry`) so a header
  and its rail cannot disagree.
- **`TVUIKitMediaItemMetrics` is an accepted adapter:** `orthogonalLayoutSectionForMediaItems()`
  exposes neither its group nor its item, so it cannot be resized. Measure what it produces once per
  width, rebuild an equivalent section at our scale, and Apple keeps owning the proportions.

## Artwork

One loader, `TVUIKitRemoteImage`: a decoded-image `NSCache` in front of the shared `URLCache`, with
a **synchronous** `cached(url:)` a cell reads while configuring. That is what stops a recycled tile
from repainting blank — `URLCache` holds bytes, not decoded images, and its memory capacity is a few
posters deep. `ArtworkLog` separates "the request failed" from "no request was made", which look
identical on screen and have opposite fixes.

## Focus

**The engine is Apple's. We do not build a layer on top of it.** No focus bridge, no shared
`@FocusState` case across siblings, no `asyncAfter` delays, no hand-rolled focus scale. The full
banned list and what each one cost is in [AGENTS.md](../../../AGENTS.md).

- **For a focusable container in SwiftUI, `.buttonStyle(.card)` and no focus code at all.** Apple's
  `DestinationVideo` sample does `#if os(tvOS) .card #else .plain #endif` on every card, applies it
  once to the enclosing stack, and fences `.hoverEffect()` to iOS/visionOS. Everything focusable
  there is a `Button` or `NavigationLink`, including pure focus stops. Do not stack `hoverEffect` /
  `scaleEffect` / `isFocused` branches on top of `.card`.
- **`.hoverEffect(.highlight)` is for controls whose label *is* the image.** The highlight attaches
  to the first `Image` in the label, so on `icon + text` it scales and shadows the icon alone.
- **True layered parallax needs layered images** (HIG). Flat posters get lift, scale, specular and
  tilt — not multi-layer parallax.
- One focus owner per interactive zone. Prefer layout-driven focus (`focusSection`, `defaultFocus`)
  over bridges. Avoid `.defaultFocus(..., .userInitiated)` unless you understand the reset.
- **A full-width `.focusSection()` on a hero band is not optional.** Apple's own guidance: without
  it, "moving focus up from the right side of the shelves below might fail, or might jump all the
  way to the tab bar" — which is verbatim the Up-from-sections bug this app carried for weeks.
- **Every state keeps a focus escape path** — see AGENTS.md. An empty list is a dead end, not a
  blank area.

### Entering a rail

- `entryItemID` — where the rail parks and scrolls (resume episode, or the first episode of the
  season the user picked). It is **not** a focus binding.
- `indexPathForPreferredFocusedView(in:)` — where focus lands when the engine *enters* the rail;
  report back out so season tabs can follow.
- **The trap:** the entry item must not be recomputed from "whichever season is selected", because
  focus travelling right into the next season selects that season — and the rail scrolls back under
  the user on every step.
- `indexPathForPreferredFocusedView` must return a path whose cell **exists right now**.

## Where we still deviate

A work list, not folklore:

- `TVUIKitPosterCell` still owns a caption fade, because `TVPosterView.title` reserves footer space
  that crops 2:3 art. `resetStaleFocusAppearance()` stays — it undoes *the system's* stranded focus
  motion, which is not the same as running our own.
- Posters occasionally strand enlarged and keep parallax-wiggling while the engine reports them
  unfocused. The reference app documents the same failure: the lockup's coordinated unfocus
  animation sometimes never runs, so no further event will fix it. Our reset exists but is not
  firing in our situation; the difference worth investigating first is that the detail page hosts
  several sibling collections at once where theirs has one. **Do not blind-fix** — it needs the
  transition watched on device.

## Reading the SDK, not guessing

`TVMediaItemContentConfiguration` and `TVMonogramContentConfiguration` are `NS_REFINED_FOR_SWIFT`:
in Swift they are **structs**, not the classes the ObjC headers declare, and the factory names are
shorter than the headers suggest — `.wideCell()` (not `wideCellConfiguration()`), `.cell()` (not
`cellConfiguration()`), badge properties at `TVMediaItemContentConfiguration.BadgeProperties.default()`
/ `.liveContent()`, and `TVLockupViewComponent`'s method is `updateAppearance(forLockupViewState:)`.
None of that is discoverable from the headers alone — it was found by compiling single-line probes
with `swiftc -typecheck` against the SDK rather than guessing through full app rebuilds. Do the same
before claiming any API limitation.

Other TVUIKit types, for reference: `TVCardView` (floating card lockup), `TVCaptionButtonView`
(button + caption, knock-out, `motionDirection`), `TVCollectionViewFullScreenLayout` (paging with
`parallaxFactor` / `maskAmount` / `contentBleed` and `didCenterCellAtIndexPath:` — a system-provided
"this card settled in the centre" hook, exactly what an autoplaying hero needs, **needs validation**),
`TVDigitEntryViewController` (PIN entry). A DEBUG-only gallery of all of them, with zero custom
focus code, lives at `Views/UILab/TVUIKitComponentGalleryView.swift` (Settings → Diagnostics).

## Verifying on device

- **There is no Simulator.app on current Xcode.** The window is hosted by **Device Hub**
  (`com.apple.dt.Devices`): focus its title bar, arrow keys + Return are the D-pad, and **Escape is
  not Menu** — use the on-screen remote's `‹` button. `simctl` has no directional-press API, only
  screenshots.
- Previews never prove focus. A static screenshot never proves smoothness. Build success proves
  nothing at all about focus — the one structural change that "built cleanly" broke navigation
  outright.
- Verify each directional case individually: Down into a show, Down into a movie, Up from every
  section, Menu from every state.
