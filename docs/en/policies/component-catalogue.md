# Policy: one component catalogue, templated pages

> Durable policy, not a dated plan. Applies to every platform, most sharply to tvOS.
> Related: [focus-and-tvui](../apple-platform/focus-and-tvui.md),
> [layout-and-containers](../apple-platform/layout-and-containers.md),
> [materials-blur-and-chrome](../apple-platform/materials-blur-and-chrome.md).

## The rule

**Pages are assembled from a fixed catalogue of components. A page is a list of typed
sections, not a hand-written stack of views.**

Two pages that show a shelf must show the *same* shelf — same component, same metrics,
same focus behaviour — not two views that happen to look similar. When a shelf is
wrong, it is wrong in one place and fixed in one place.

This is the single most violated rule in this codebase's history. Every regression
worth remembering came from a screen growing its own copy of something that already
existed: a second "big rating number" style beside `TypeScale.ratingAggregate`, three
independent poster shelves on the detail page each with its own focus state and menu
coordinator, a hand-rolled `ExpandableButtonStyle` where `.card` was meant, section
headers written inline in the information table instead of `SectionHeader`.

## Where the catalogue comes from

TVML's `productTemplate` is the reference specification, and it is not nostalgia:
Apple deprecated the *transport* (XML + a JS engine), not the design. What Apple's
current SwiftUI tvOS guidance describes — a showcase header at ~80% of the viewport,
shelves below the fold, snapping at the fold, a material gradient over the artwork —
is the same page, restated. Read `productTemplate` as the spec of what a media detail
page **is**, then build it from native parts.

Most of those parts already exist natively; TVUIKit is the surviving edition of the
same lockups. Reach for these before writing anything:

| Concept (TVML name) | Use |
| --- | --- |
| `banner` | above-the-fold region: `containerRelativeFrame(.vertical) { l, _ in l * 0.8 }` + full-width `.focusSection()` |
| `heroImg` / `background` | one wide still + `.regularMaterial` masked by a `LinearGradient` whose stop opacities animate |
| `shelf` / `section` / `lockup` | `MediaPosterShelf`, `TVUIKitMediaItemRail` (wide), `TVUIKitMediaCollection` / `TVPosterView` (2:3) — see [the tvOS cell standard](#the-tvos-cell-standard) |
| `monogramLockup` | `TVMonogramContentConfiguration` — it draws the circle, the background and the initials from `personNameComponents`; set `image` when there is a photo, and never hand-pick any of it |
| `buttonLockup` | `TVCaptionButtonView`, or a `Button` whose label is a `Label` |
| `badge` / `textBadge` | an `Image` from the asset catalogue; badges are artwork, not text |
| `productInfo` / `infoTable` | the About block's columns — a table, quiet, free to grow |
| `description handlesOverflow` | `InfoPopup` (KinoPubUI) — **the clipped content is the trigger**, never an `i` button beside it. `expandsIntoInfoPopup(title:)` wraps the paragraph or column itself; presentation is a sheet, drawn as a centred panel over a scrim on tvOS |
| section header | `SectionHeader` — and on tvOS it never navigates (no chevron, no `NavigationLink`) |

No native equivalent exists for `ratingCard`, `reviewCard` and the `ratingBadge` bar.
Those we own — which means they too live in exactly one place.

## The tvOS cell standard

> User decision, 2026-08-10. On tvOS there are **three cells and one collection**. Not
> three cells *preferred* — three cells. A tile assembled by hand out of image views,
> labels and a progress bar is a defect even when it looks right, because the system
> already ships that tile and ours drifts the moment two screens need it.

API facts below are read out of
`AppleTVOS27.0.sdk/System/Library/Frameworks/TVUIKit.framework/Headers`, not from memory.

| What is on screen | The cell | What the system already does for you |
| --- | --- | --- |
| A **person** — actor, director, anyone with a face and a name | `TVMonogramContentConfiguration.cell()` as a cell's `contentConfiguration` | Draws the circle, the focus motion, and the localized initials from `personNameComponents` when `image` is nil. Photo goes in `image` — a monogram is the *fallback*, never the intended look for someone we have a portrait of. |
| A **wide 16:9 thing** — movie still, episode, trailer, Continue Watching, genre / category tile | `TVMediaItemContentConfiguration.wideCell()` | `image`, `text`, `secondaryText` (`"S1, E1"`), `playbackProgress`, `badgeText` + `badgeProperties` (incl. `liveContentBadgeProperties`), `overlayView`, `focusedFrameGuide`. Every part of an episode tile is a property on this struct. |
| A **2:3 poster** | `TVPosterView` (the `TVLockupView` family) | Focus lift, specular, and `focusSizeIncrease` computed from the image. There is **no** poster variant of the media-item configuration — the header's only factory is `+wideCellConfiguration`. Do not go looking for one again. |

And the container:

- **Layout comes from `NSCollectionLayoutSection.orthogonalLayoutSectionForMediaItems()`.**
  That is the system's own rail: item size, gutter, content insets, focus room. Hand-tuned
  `itemSize` / `minimumLineSpacing` on a flow layout is the thing this replaces.
- **One `UICollectionView` per page region, with several sections in it** — not one bridged
  `UIViewControllerRepresentable` per rail stacked in a `VStack`. Sections are what a
  compositional layout is for; separate bridges are separate focus owners, separate
  reload cycles, and separate places for metrics to drift.

Rules that follow from the table:

1. **An episode tile *is* a Continue Watching tile.** Same component, same file; only
   `text` / `secondaryText` / status differ. If the episodes rail and the Continue
   Watching rail are two different views, that is the catalogue rule being broken —
   the tile is the same object in the product.
2. **The caption lives in the configuration**, under the artwork, in `text`. Not a
   `UILabel` we position over the image, not gated on focus. (`secondaryText` renders
   nothing for us — see "One label under a tile" below.)
3. **`overlayView` is the only sanctioned place for anything of ours** over the artwork,
   and it stays one view with one look (see `TVUIKitMediaItemOverlayView`).
4. **Type styling goes through `textProperties` / `secondaryTextProperties`** (`font`,
   `color`) — the only styling knobs those configurations expose, and therefore the only
   ones allowed. If tvOS type ends up looking worse than the iOS/macOS rail, that is a
   bug in what we set, not a licence to hand-draw the cell.
5. **No custom `didUpdateFocus`, `scaleEffect`, shadow or stale-appearance reset** on a
   cell that has a system content configuration. Needing one means the wrong cell is
   in use.

### Sizing and air

Two numbers are decided once, in `ShelfMetrics`, and everything else is derived:

- **The card width is pinned, not divided.** `tvCardWidth` / `tvLandscapeCardWidth` are
  what a tile *is*; the container decides how many fit, never how big they are. Dividing
  the container by a column count is what made the same poster a different size in a
  full-width Home rail and in a grid beside a sidebar. `ShelfMetrics.fixedCardWidth`
  carries this; the leftover becomes slack (centred, in a grid).
- **Gutters and focus room are derived from the growth, not chosen.** A focused tvOS
  tile grows ~10% of its own size, half of it into each neighbour's side of the gap, so
  a constant gutter reads fine at rest and collides on focus — which is exactly what a
  20pt gutter under a 290pt poster did. `ShelfMetrics.tvGutter(cardWidth:)` and
  `TVUIKitPosterMetrics.focusGrowthPadding(tileHeight:)` are the one rule; no rail,
  grid or avatar strip gets its own spacing constant.
- **The page margin is `max(design margin, the container's own safe-area inset)`.**
  Screens differ — a grid already sits inside SwiftUI's safe area, while the detail page
  ignores it horizontally and has to supply the overscan margin itself. A sum would
  double-inset one of them; the larger of the two is right in both, and never lands
  content in overscan. Measured, not assumed: `ShelfGeometry` carries width and safe
  area out of one `onGeometryChange` so a header and its rail cannot disagree.

Artwork has one loader, `TVUIKitRemoteImage`: a decoded-image `NSCache` in front of the
shared `URLCache`, with a **synchronous** `cached(url:)` a cell reads while configuring.
That is what stops a recycled tile from repainting blank — `URLCache` holds bytes, not
decoded images, and its memory capacity is a few posters deep. `ArtworkLog` separates
"the request failed" from "no request was made", which look identical on screen and have
opposite fixes.

### Where we deviate today (2026-08-10)

Recorded so the gap is a work list, not folklore:

- **`TVUIKitContinueWatchingCell` is a hand-built tile** (`TVCardView` + image view +
  two labels + a hand-drawn progress track). It now backs only landscape *grids*; it
  should die into the media-item cell rather than survive as a second wide tile.
- **`TVUIKitPosterCell` still owns a caption fade.** Scale mirroring is gone — the
  overlay is a child of `TVPosterView.imageView` and rides the system's transform — but
  the on-focus caption is still ours, because `TVPosterView.title` reserves footer space
  that crops 2:3 art. `resetStaleFocusAppearance()` stays: it undoes *the system's*
  stranded focus motion, which is not the same thing as running our own.

Fixed on 2026-08-10, kept here because the *shape* of the answer generalises: the cast
rail was already on `TVMonogramContentConfiguration`, so the initials-everywhere look
was never a component choice. `TitleMetadata.enrich` matches credits by normalized name
and normalizing only folds diacritics — kino.pub returns "Реми Безансон" where TMDB
returns "Rémi Bezançon", so a payload with 26 photos matched none of them and every
`photo` stayed nil. The fix was in the photo path (always resolve the pushbr URL, which
is keyed by the kino.pub name we already hold), not in the cell. The person page now
draws the same circle rather than a poster-shaped `CastAvatarView`.

**Matching credits across alphabets is still unsolved** — pushbr covers it today; TMDB
photos and `tmdbPersonId` remain unreachable for Cyrillic credits.

Also fixed that day: **the episodes rail is now the Continue Watching rail.**
`SeasonsRailView.episodeRail` on tvOS is `TVUIKitMediaItemRail`, and the four episode
states that `TVUIKitMediaItemStatus` had modelled but nothing used are now what draws
them — an unaired episode is `.upcoming` with its date in the system badge, not a
dimmed copy of a playable card. Two API additions made the bridge possible without a
second focus owner, and both are the native hook rather than a push from outside:

- `entryItemID` — where the rail parks and scrolls (resume episode, or the first episode
  of a season the user picked). It is **not** a focus binding.
- `indexPathForPreferredFocusedView(in:)` — where focus lands when the engine *enters*
  the rail; `onFocusedItem` reports back out so the season tabs can follow.

The trap to remember: the entry item must not be recomputed from "whichever season is
selected", because focus travelling right into the next season selects that season — and
the rail would scroll back under the user on every step.

### One label under a tile, and the artwork stays clean

> User decision, 2026-08-11, replacing the two-line attempt of the day before.

- **One text line.** `configuration.secondaryText` produced nothing visible on screen, so
  the second line cost a wider tile and bought nothing. Treat the tile as having a single
  caption and pack what matters into it. The one lead never tried, if it is ever wanted
  back: Apple's sample builds the configuration as
  `wideCell().updatedConfiguration(for: state)` and we never call that.
- **Nothing large goes on the artwork**, and **no dates under it** — an announced episode
  says so in its top-corner badge; repeating it below is the same fact twice. What is
  allowed over the image: the badge, the progress bar, the duration chip, the
  watch-status glyph.
- **No lockups, no footer views.**
- **Apple's own episode cell is two focus areas** — banner and description, separately
  focusable. Deliberately not copied: kino.pub has no episode pages, and the context menu
  already covers the secondary actions.

Caption formats, because they differ by surface:

| surface | caption |
| --- | --- |
| Continue Watching / history | `S2 E4 • Episode Name` — the season matters when the rail spans shows |
| a season rail | `7. "Episode Name"` — the season is already named by the tab above |

Both come from `TVUIKitCardText`.

**The progress bar is ours, not `playbackProgress`.** The system's only paints on the
*focused* tile, and "started, not finished" is exactly what an idle rail has to say, so
`config.playbackProgress` is set to 0 and the bar lives in
`TVUIKitMediaItemOverlayView`. That is a deliberate exception to "let the system draw
it", taken with the trade stated: we own a bar, and in exchange it is visible when it
matters.

### One wide tile, one poster tile — no per-screen variants

Landscape **grids** (history, library) used to use a hand-built
`TVUIKitContinueWatchingCell`: `TVCardView` plus labels positioned over the artwork, so
the same show read one way in a rail and another way in a grid. Deleted 2026-08-11;
`TVUIKitMediaCollection` now dequeues the same `TVUIKitMediaItemCell` the rails use.

### The poster experiment, and why it was reverted

Tried on 2026-08-10 and reverted on 2026-08-11 — recorded so it is not tried again by
accident. The attempt pinned `TVPosterView.contentSize`, set the image view to
`scaleAspectFill` with `clipsToBounds`, rounded that view, and added a second label plus
focus-only play/duration chrome. On screen it was worse in three ways:

1. **Aspect-fill crops posters.** 2:3 source art is what the artwork already is; filling
   a fixed box cuts it.
2. **`clipsToBounds` on the image view kills the parallax.** The lockup's tilt moves
   content inside its own frame, and clipping that frame removes the effect that makes a
   tvOS poster feel native. This is the expensive lesson: it is not obvious from the API.
3. The second label was the same change that produced nothing on the wide tile.

What survived the revert: the decoded-artwork cache lookup in `loadImage`, which changes
nothing visually except that a recycled tile stops going blank.

Still true, and the reason the overlay sits where it does: the overlay must ride the
system's focus transform, and the only two places it can be are a child of the poster's
image view (which forced the clipping above) or a sibling that mirrors the scale by hand.
The cell is back on the sibling. If hand-mirroring is to go away again, that trade has to
be solved, not assumed away.

## Native first, and at the right level

- Prefer the system control over a custom one. `.card` / `.borderless` / `.plain`
  carry the platform's focus motion for free; a custom `ButtonStyle` re-implements it
  worse and then has to be maintained.
- Assign the button style **on the outside of the container**, not per item. A shelf
  holds one kind of lockup.
- A `ButtonStyle` cannot apply another button style to its own `configuration.label` —
  that line does nothing. If a call site needs native focus, change the call site.
- State that drives a page-wide appearance must have exactly **one writer**. Two
  writers racing one flag has broken this page twice (`washProgress`, then the fold).

## Trying designs is allowed — divergence is not

While a component's look is unsettled, it is fine to keep **2–4 variants of that one
component** side by side behind a switch, so they can be compared on real data. That is
exploration and it is encouraged.

What is not allowed is the same idea implemented twice in two places because two
screens needed it. The variants must be variants *of one component*, in one file, and
the losers get deleted once a winner is picked — along with the switch.

## For agents working in this repo

Before writing a view, answer these:

1. Does this already exist in the catalogue above, or in `KinoPubUI`? Use it.
2. Is there a system component (SwiftUI, UIKit, TVUIKit) that does it? Use that.
3. Am I about to write focus, scale, shadow or blur by hand? Almost certainly the
   platform already has it — check before hand-rolling.
4. If it is genuinely new: put it in `KinoPubUI` as one component, used by name, and
   add it to this table.

A screen-specific copy is a defect, even when it looks right.
