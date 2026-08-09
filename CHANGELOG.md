# Changelog

Notable shipped changes and implementation facts future agents need. Trivial copy/token churn does
not belong here. Detail checklists live under [`docs/en/features/`](docs/en/features/).

## Unreleased

### Detail page

- **Library sidebar (macOS + tvOS) no longer traps a title's detail page beside itself.**
  `LibraryShellView`'s `NavigationStack` wrapped only the detail pane, a sibling of the permanent
  sidebar in an `HStack` — every route pushed through it, including the full-bleed `MediaItemView`,
  stayed confined to that pane's width forever. Every other tab wraps its whole content in one
  `NavigationStack`, which is why detail pages cover the full tab there. The stack now wraps sidebar
  + detail together; section switching is separate state (`LibraryModel.selection`), not a stack
  push, so it is unaffected.
- **tvOS hero title gets its own contrast, on top of the existing full-width scrim.** Rivulet's
  diagonal bottom-leading → top-trailing scrim reads well for them because their hero text is one
  narrow left-hand column; ours runs the full bottom edge (title + actions on the leading side,
  synopsis / credits / metadata filling the trailing side), so a pure diagonal would starve the
  right column of contrast. `titleScrim` adds diagonal weight only over the title block —
  `bottomScrim` still holds the floor full-width for everything else.
- tvOS scroll-progress scrub (`washProgress`) actually scrubs now — `MediaItemHeroView.effectiveWash`
  returned `max(washProgress, 1)` (always 1), so the material veil was a binary flip on
  `isHeroOnScreen` rather than continuous. Returns `washProgress` directly.
- **Reverted same-day:** pulling the hero out of the scrolling `VStack` into a fixed `ZStack` layer
  (meant to stop scroll jitter between Play / Watched / Watchlist). Broke tvOS focus outright on
  device — stuck on Play, Down/Up dead ends, Menu closed the app instead of popping. Full account in
  [detail-page-choreography](docs/en/plans/detail-page-choreography.md).
- **Root cause of the above, found and fixed same day:** six hero buttons (watchlist, bookmark,
  watched, trailer, more, plus the non-tvOS plot branch) shared one `@FocusState` equals-value,
  `MediaItemFocusTarget.heroOther`. Ambiguous — the engine could not resolve which view was actually
  focused, so focus froze dead on Play (Right and Down both no-ops, on sparse *and*
  fully-populated titles alike) and Menu popped past the tab's own grid straight to the system
  Springboard instead of the detail page. One case per button now. Confirmed on-device: Down walks
  hero → Ratings → Cast & Crew → Information cleanly, Up restores the sharp hero exactly, Menu pops
  correctly.
- tvOS shadows removed from cards, badges, and action chrome that render per-item in a scrolling
  shelf or animate their radius with focus — real, measured cost, not just visual noise:
  `MediaCardView` (watched/bookmark/editorial glyphs), `HomeBannerCardView`, `PosterStyle`,
  `MediaActionButtonStyle` (hero Play pill + circle buttons), and `PortraitButtonStyle` (cast/crew
  circles — this one's radius *animated* on every focus change, the worst of the set). Hero title
  text shadow removed too, in favor of the `bottomScrim`/`titleScrim` contrast already in place —
  confirmed synopsis text still reads over a bright backdrop without it.
- Rating tiles (`RatingTile` / `AggregateRatingTile` / `ViewsRatingTile`) had **zero** tvOS focus
  feedback — the custom button style only read `isPressed`. First attempt used
  `.hoverEffect(.highlight)`, which was **wrong and had to be redone the same day**: the tvOS system
  highlight attaches to the first `Image` in the label, so on an `icon + number + caption` tile it
  scaled and shadowed the *logo alone* while the tile sat still (and it was the highlight, not the
  asset, drawing those icon shadows). Now `DetailTileFocusChrome` — `scaleEffect` + `brightness` on
  the whole label, via a `ButtonStyle` for the real buttons and `@FocusState` for the two focus-stop
  tiles. That hand-rolled chrome was then **itself replaced the same day by `.buttonStyle(.card)`** —
  the system card style — after the user pointed at Apple's `DestinationVideo` sample, which applies
  `#if os(tvOS) .card #else .plain #endif` to every card and writes no focus code, fencing
  `.hoverEffect()` to iOS/visionOS. All four controls now share `DetailTileStyle.buttonStyle`; the
  two that were focus stops rather than actions became `Button {}`, which is how that sample makes
  everything focusable too. **Rule in `focus-and-tvui.md`:** for a focusable container on tvOS reach
  for `.card` first and write no focus code; `.hoverEffect(.highlight)` is only for controls whose
  label *is* the image.
- **`FeatureFlags.fakeSeasonsOnMovies` — temporary DEBUG diagnostic, delete on sight.** Synthesises
  one season of six unplayable episodes onto titles that have none, to test whether the hero
  blur/scroll choreography only behaves when a season rail sits under the hero. **It did:** movies
  with a fabricated rail started blurring like series, which pinned the cause below.
- **Detail hero wash is section state, not scroll offset.** `washProgress` was `scrollOffset / 600`,
  and the page only scrolls as far as it must to reveal the next focusable thing — so a tall season
  rail produced a full wash while a movie's short first section (ratings) produced almost none. The
  blur was a function of content geometry, and arrived in uneven steps because every focus move
  scrolled a different distance. It also wrote state on **every scroll frame**, re-running the
  detail page's body and re-rendering every shelf below it (each `TVUIKitMediaCollection`'s
  `updateUIViewController` included) — the likely source of the reported scroll lag, and a suspect
  for the stranded multi-poster focus bug. `washProgress` and `onScrollGeometryChange` are gone:
  `effectiveWash` is `isHeroOnScreen ? 0 : 1`, `chromeAlpha` is `isHeroOnScreen ? 1 : 0.35`, one
  animation clock, written only by "focus entered a hero control" / "a section reported focus".
- Every detail content section that lacked one now declares `.focusSection()` (vote, cast, awards,
  photos, similar, both person shelves, info columns), so focus travels section-to-section rather
  than creeping element-by-element. Ratings and `SeasonsRailView` already built their own.
- Hero `titleScrim` was not missing, it was half-strength: ours shipped `0.5 → 0.18 → clear` where
  Rivulet's `ScrimGradientView` is `0.92 → 0.55 → clear` (stops `0 / 0.45 / 1`, bottom-leading →
  top-trailing). Over a bright backdrop that reads as no scrim at all. Matched to the reference
  values.
- Tab bar shown at rest on the detail page again (was unconditionally hidden there on tvOS/iOS);
  iOS/iPad additionally opt out of the system's scroll-driven minimize
  (`.tabBarMinimizeBehavior(.never)` — unavailable on tvOS/macOS in this SDK, so that half is
  iOS-only). **Known follow-up bug, not fixed:** returning from the detail page can leave the tab
  bar area blank instead of it reappearing; full account and a proposed direction (stop treating the
  bar as chrome that independently hides/shows — Apple's own tvOS apps don't duplicate a bar layer
  over content the way ours does) are in
  [detail-page-choreography](docs/en/plans/detail-page-choreography.md).
- Fixed one of two writers racing `washProgress` on Up-back-to-hero: `MediaItemHeroView.chromeAlpha`
  read the raw (possibly stale, scroll-overwritten) value directly, unlike
  `MediaItemHeroBackdrop.effectiveWash`'s pre-existing `isHeroOnScreen` guard — so the backdrop
  snapped sharp correctly while the title/button chrome kept re-dimming in step with the still-settling
  scroll. Same guard added to `chromeAlpha`. Confirmed no navigation regression; the visual smoothness
  itself needs eyes-on, not a screenshot, to confirm — see
  [detail-page-choreography](docs/en/plans/detail-page-choreography.md) phase 4.5.

### Ratings

- **Our combined score is behind `FeatureFlags.combinedRatingEnabled`, currently off** (the value
  lives in `KinoPubUI.RatingFeature.combinedEnabled` because card chrome reads it inside the
  package). Off hides the poster plaque, the hero pill, the detail "Rating" tile and the whole
  card Rating placement / source settings section. IMDb and Kinopoisk show only under their own
  logos — `MediaScoresView` in card captions and in the hero meta line.
- `Rating` now averages **weighted by vote count**: 6.0 from 4,867 voters next to 1.0 from 7 is a
  6.0 title, where the plain mean printed 3.5. A source that reports no count weighs as one vote,
  so two countless sources still average evenly. Votes on an unrated source never enter the mean.
- Tier boundaries match their own documentation again: `average` is 6.0–7.0, so 5.9 is `poor`
  (the switch said `5..<7`, and `testTierBoundaries` had been failing against it).
- Ratings tiles keep their natural width inside a horizontal scroll, like every other section.
  Squeezing them into the page width had been wrapping "Кинопоиск" mid-word.
- A source with voters but no published score (Kinopoisk counts votes long before it prints a
  number) gets its own tile: an em-dash and "Not enough ratings yet", instead of vanishing.

### One landscape card

- Episodes now draw `MediaCardView` — the same landscape card as Continue Watching and History.
  `SeasonsRailView`'s private `EpisodeRailCard` / `EpisodeCardButtonStyle` and the season grid's
  `SeasonItemView` are gone.
- `MediaCard(episode:in:title:episodeLabel:dateLabel:stillURL:primaryAction:)` in `KinoPubUI` is the
  single mapping (ids, resume fraction, watched flag, runtime); callers pass only the strings the
  payload cannot compose. `MediaCard(unavailableEpisodeID:…)` covers schedule-only episodes.
- Caption never says the same thing twice: a name that is only the episode's own number — "Эпизод 1"
  against `Episode 1`, in any UI language — counts as no name, and the card falls back to
  "Episode 1" as the title with the date alone underneath. Named episodes keep
  name / "Episode 3 · Jul 22, 2026".
- Air dates carry the **year** (a rail spans seasons, so a bare "8 Jul" says nothing), and inside a
  week either way they are relative instead — "in 3 days", "7 days ago", "tomorrow".
- Rail metrics come from `ShelfMetrics.landscape` + `CardAspect.landscape` against the measured
  rail width, so episode cards sit on the same grid as every other landscape shelf instead of a
  fixed 480/300pt. Focus is the shelves' `.borderless` lift, not a bespoke plate.
- The rail keeps `contentMargins` (not `padding`) for its inset: `scrollTo(anchor: .leading)` on a
  season tab would otherwise park the first episode under the page inset.
- Play affordance is one per platform, never two: iOS/iPadOS keep the play glyph inside the time
  chip and draw **no** centre play chrome; tvOS/macOS keep the centre glyph on focus / hover and
  the chip is bare time. The watched checkmark stays in the chip everywhere.

### tvOS card size beside a sidebar

- Sizing already read the **container** width, not the screen — every shelf and grid measures
  itself with `onGeometryChange`. What was screen-shaped was the *rule*: `ShelfMetrics.posters`
  gave TV six columns only from 1600pt up, and anything narrower fell into the handheld table. The
  Library shell's 420pt tvOS sidebar leaves ~1500pt, which read as "wide tablet" — 8 columns, a
  **150pt** poster where the full screen draws 290pt.
- On tvOS the column count now comes from a target card width (`ShelfMetrics.tvCardWidth` 290,
  `tvLandscapeCardWidth` 352) instead of the width table, so a narrower container gets fewer cards,
  never smaller ones: 1920 → 6×290 / 5×352 (byte-identical to before), 1500 → 5×268 / 4×340.
  Landscape stops being "posters minus one column", which overshot once the count got small.
- Other platforms keep the width table unchanged — there a 1500pt canvas really is a wide window
  at arm's length.

### tvOS context menus on TVUIKit cards

- Long-press-Select opens the card menu on the `TVUIKitPosterCell` / `TVUIKitContinueWatchingCell`
  path again (Home rails, catalog grids, search results — everything behind
  `FeatureFlags.tvUIKitPosters`). It had been silently dead: the `UIContextMenuInteraction` sat on
  each cell's `contentView`, and tvOS delivers remote presses to the **focused** view and up its
  responder chain, so an interaction on a descendant of the focus item never sees the gesture.
- The menu now comes from `TVUIKitMediaCollectionController`'s
  `collectionView(_:contextMenuConfigurationForItemsAt:point:)`, which is the hook UIKit wires to
  the focus engine — and the only one that exists on tvOS: the single-indexPath variant is
  `API_UNAVAILABLE(tvos)`, the `…ForItemsAtIndexPaths:` one is tvOS 17+. Entries still come from the
  same `contextMenuProvider` and `TVUIKitContextMenuBuilder`, so SwiftUI and TVUIKit cards show the
  same items.
- Dismissing the menu resets the visible poster cells' focus appearance, the same
  `resetStaleFocusAppearance()` workaround focus changes already need — `TVPosterView` can otherwise
  stay stranded at its enlarged size after the preview hands the cell back.

### iPad tab bar

- Shaped like tvOS: Search glyph first, Settings **gear** last (icon-only, title kept as the
  accessibility label), words in between. Search no longer uses `Tab(role: .search)` — that role
  pinned it trailing next to Settings. iPhone keeps the role (bottom-bar HIG) and gets `gear` too.
- Subscription-days badge is off the Settings tab (both iOS layouts); `subscriptionDaysBadge` is
  gone with it. Days left still show inside Profile.

### Detail — people shelves

- "More from \<director\>" / "More with \<actor\>" rails under Similar on the item page. First
  credited name only, `LibraryFilter.person` + Kinopoisk sort, skeleton while loading, hidden when
  empty. Title taps push `PersonItemsView`. Actor queries send `cast=` (live API), not the docs'
  `actor`.

### Detail hero

- Two columns on tvOS/macOS instead of three: **title + actions** (fixed width) | **synopsis,
  credits, facts** (fills the rest). The "starring" column is gone; its lines moved under the plot.
- Column order inside the written column is synopsis → genres · country / cast / director →
  year · runtime + score + chips. Facts sit at the foot, not the head.
- Actions are a vertical stack: Play pill, then one row of identical circles. `plus` follows the
  series (`togglewatchlist`), `bookmark` opens folders, `checkmark` marks watched, `film` plays the
  trailer. The first two used to be the same folder menu; `isInWatchlist` was never seeded from the
  API, so the follow control always opened as "not following" and the first tap unfollowed.
- Watched checkmark shows for films and series whenever anything is unwatched (was: only mid-title),
  and hides once everything is watched. A series asks episode or season;
  `MediaItemModel.toggleWatched(season:)` uses `/v1/watching/toggle` with a season and no video
  number, then refetches — the bulk response carries no per-episode flags.
- Aggregate `RatingBadgeView` (the poster badge) replaces the split IMDb/Kinopoisk scores.
- Age-rating chip is **opt-in** (`MediaItemDisplayPreferences.showAgeRatingBadge`, Settings →
  Details → Metadata). Still always listed in the information table.
- Overflow moved from a hero circle to the navigation toolbar on iOS/macOS; tvOS keeps the circle.
- No navigation bar on the item page (iOS/macOS): hidden toolbar background, empty title.
- Ambient trailer is off on iOS pending a phone hero that gives the picture room.
- macOS `TrailerLayerHostView` now uses `makeBackingLayer()` so the `AVPlayerLayer` *is* the backing
  layer. It was a sublayer under a `layer` assigned after `wantsLayer`, which left the view
  host-backed: `layout()` did not reliably fire and aspect-fill rendered at a stale frame size.

### Typography

- `TypeScale.detailBody` (`.body`) is the single running-text size on the item page — hero metadata,
  synopsis, credit lines, rating vote counts, and every information-table row. They were four
  hand-picked sizes between 12 and 15pt. Rule recorded in
  [apple-native-design](docs/en/policies/apple-native-design.md): always a Dynamic Type text style,
  and when unifying sizes, unify **up**.

### Documentation

- Rebuilt agent constitution ([AGENTS.md](AGENTS.md)), Cursor rules, policies, feature-stage docs, and
  English Apple-platform knowledge base.
- README reduced to public overview + eight macro stages; minutiae moved to feature docs.
- July 2026 research and notes export archived under [`docs/archive/`](docs/archive/); duplicate
  `research/en` + `research/ru` trees removed.
- Continuity policy replaces the old absolute “no skeletons” rule: stale-first rendering first;
  exact-layout skeletons only on true cold loads.

## 2026-08 — Native UI remediation (historical)

Agent-relevant facts from the remediation pass (verify in code before assuming still true):

- Home: contained 16:9 banner shelf; Netflix `showsFeaturedPreview` path deleted.
- Blur: private `CAFilter` `variableBlur` over static art; Metal progressive blur removed; no blur
  over video on tvOS/macOS.
- Hero CTAs: white Play pill + translucent secondaries (not Liquid Glass on hero).
- Navigation: unified `Route` + `RouteDestination`; zoom transitions on iOS/tvOS.
- Detail: single vertical `ScrollView` (offset slideshow removed).
- Playback: app-scoped `PlaybackSession` (one `PlayerManager` at a time).
- Shell: shared `.sidebarAdaptable` `TabView`; macOS profile via `tabViewSidebarBottomBar`.
- Caching: `ContentStore` list-row cache for Home/Library summaries shipped; item-facts TTL and
  paginated grid cache still open ([01-foundation](docs/en/features/01-foundation-continuity.md)).

## Earlier

See git history and dated plans under [`docs/en/plans/`](docs/en/plans/) /
[`docs/archive/plans/`](docs/archive/plans/) for pre-remediation modernization work.
