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
| `description handlesOverflow` | truncated text in a `.plain` `Button` + `fullScreenCover` |
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
2. **The caption lives in the configuration**, under the artwork, in `text` /
   `secondaryText`. Not a `UILabel` we position, not gated on focus.
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

### Two lines under a tile, and the artwork stays clean

> User decision, 2026-08-10. This closes the question below it, which is kept as the
> reasoning that led here.

- **Two text lines, maximum: a label and a subtitle.** A third line is not a layout
  problem to solve, it is a decision made against. Anything that does not fit gets
  packed *into* those two, and if the subtitle turns out not to work, into one.
- **Nothing large goes on the artwork.** Only a badge, the progress bar, the duration
  chip and the watch-status glyph — all small, all already there. The images are small
  to begin with; anything more would need a blur or scrim to stay clean, and that is a
  bigger job than it is worth right now. (A mirrored/specular treatment is parked as a
  someday experiment, not a plan.)
- **No lockups, no footer views yet.** Ship what `TVMediaItemContentConfiguration`
  already exposes.
- **Apple's own episode cell is two focus areas** — the banner and the description
  beneath it, each separately focusable, one playing and one opening the episode page.
  Deliberately not copied: kino.pub has no episode pages, and the context menu already
  covers the secondary actions.

How it is built:

| Cell | Line 1 | Line 2 |
| --- | --- | --- |
| wide (`TVUIKitMediaItemRail`) | `configuration.text` | `configuration.secondaryText` |
| poster (`TVUIKitPosterCell`) | its own `captionLabel` | its own `subtitleLabel` |

The poster pair is ours because `TVPosterView.title` / `.subtitle` reserve footer space
that crops 2:3 art — the reason both were nil there in the first place.

Both lines come from **`TVUIKitCardText`**, which reads the same
`MediaCardDisplayPreferences` the SwiftUI card does (`showOriginalTitle`, `showYear`,
`showGenre`, `showCountry`). The display settings that already existed keep working on
tvOS instead of the platform growing a fixed format of its own; which fields belong on
which surface is still the user's to set, and will be fixed later.

What is on the poster's artwork, and when (user decision, 2026-08-11):

| chrome | shown |
| --- | --- |
| progress bar | **always** — "started, not finished" is a fact the tile must state while you are nowhere near it |
| watched checkmark | always |
| play glyph, duration | **on focus only** — the cover is already the title; idle tiles stay clean |
| both text lines | on focus only |

The poster card is a **fixed 2:3 rectangle with the artwork aspect-filled**, not a box
sized by the image. `TVPosterView` takes its proportions from the image's natural size
unless given a `contentSize`, which made a rail of posters jump in height and — since
the overlay is a child of the image view — made the overlay stop short of the card's
edges on placeholder tiles. Rounding lives on that image view too: it used to come from
the overlay while the overlay was a sibling covering the image, and moving it inside left
the corners square.

The two poster labels must read as *different things*: title in `.callout` at `.label`,
metadata in `.caption1` at `.secondaryLabel`. Same size and colour for both reads as one
wrapped sentence.

An **announced episode's date goes through the system badge** (`configuration.badgeText`),
the same corner chip 4K and HDR use, and outranks a capability badge — 4K on something
unwatchable is not the useful fact. The cost: `badgeText` takes a `String`, so the clock
glyph cannot ride along with the date. "Watched" stays on our overlay, because it is
paired with the scrim and checkmark the system badge knows nothing about.

Open check: whether the system draws `secondaryText` under the wide tile or over the
artwork's bottom-leading corner, where our glyph and time chip sit. The gallery's
**"Caption lines"** row is there to judge it. If it draws over the artwork, the wide
tile packs down to one line — the poster cell shows what the clean alternative would
cost (labels of our own, i.e. the footer work that is deferred).

### Why one line was not enough (the reasoning behind the decision above)

Open requirement, recorded so the next pass does not re-litigate it. A tile currently
carries **one** line (its name), and that loses to what kino.pub already shows.

- **Posters** need a metadata line under the title: year at minimum, plus some of
  country / original title / genre / type / season-and-episode counts. Which fields is a
  user setting, not a constant — the app has always let this be configured.
- **Wide tiles** have more room and need more: Continue Watching wants at least two
  lines, an episode wants its title, its meta, and its synopsis.
- **On focus the tile should become a real card** — a background appears, it may grow
  substantial. That is a design direction, not a spec, and it is not built.

`TVMediaItemContentConfiguration` offers exactly `text`, `secondaryText`, `badgeText`,
`overlayView`, `playbackProgress` — enough for the MVP, which is what the decision above
settles on. The episode synopsis and the "tile becomes a full card on focus" idea are
**not** part of it; they would need the footer / lockup work that is deferred.

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
