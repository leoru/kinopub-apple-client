# Changelog

Notable shipped changes and implementation facts future agents need. Trivial copy/token churn does
not belong here. Detail checklists live in [ROADMAP.md](ROADMAP.md).

## Unreleased

### Docs: one context file, five skills, and constraints that stop becoming requirements (2026-08-13)

- **The documentation tree collapsed into [AGENTS.md](AGENTS.md) + [ROADMAP.md](ROADMAP.md) +
  `.claude/skills/`.** `docs/en/policies/`, `docs/en/apple-platform/` and `docs/en/features/` are
  gone as folders: durable rules are one always-on file, how-to knowledge loads on demand
  (`tvos-surface`, `apple-chrome`, `player-avkit`, `metadata-service`, `docs-upkeep`), stage
  checklists are one roadmap, and every dated plan moved to `docs/archive/plans/` with a note at the
  top saying what survived it. Before: ~23.6k words of always-relevant docs plus 21.6k words of
  plans that agents kept reading as law. The rule that keeps it that way: **a line in AGENTS.md must
  carry either the default or the cost of getting it wrong.**
- **Constraints are not requirements.** Every limitation gets one of four labels — Apple API /
  performance / focus invariant / product decision — and only the last two may become durable
  requirements; the first two become one named adapter. Three registers came with it: banned
  patterns (focus bridges, shared `@FocusState` cases, manual focus delays, hand-rolled focus
  chrome, continuous scroll-progress choreography, hand-driven `contentOffset`, custom hero focus
  graphs, SwiftUI preview state machines, screen-specific component variants), invalid
  agent-invented "requirements", and the two adapters that are allowed to exist.
- **Voided as requirements:** the detail page's scroll-progress scrub (`washProgress`), "hero lives
  outside the scrolling container" (only the *artwork layer* does — hero content stays in one focus
  graph with the sections), the overlay title logo / compact title, and tab-bar pinning. The
  detail-page plan is now explicitly history, with a table of what survived.
- **Renderers differ by platform on purpose:** tvOS media surfaces are UIKit + TVUIKit; iOS/iPadOS/
  macOS are SwiftUI including `.navigationTransition(.zoom)`. Shared: models, services, view
  models, component semantics, tokens, assets — never view hierarchy or geometry. Cross-platform
  geometry parity (the two-line tvOS poster caption) is named as the anti-pattern it was.
- **`badgeText` can carry a glyph** — an SF Symbol is a character. "The system badge cannot show an
  icon" was never a reason for a parallel overlay system.
- **The playable graph** ([ROADMAP](ROADMAP.md#4--kinopub-catalog-completeness)):
  episodes, trailers, parts and versions are one `PlayableItem` rail, with `PlaybackVariant` under
  it (kino.pub ships 24/48 fps as `s0e1`/`s0e2` — item 124447 is the probe). Detail pages lead with
  what can be played. The kino.pub endpoints to map before more detail UI are listed there.

### The info popup, and hero buttons that are actually the system's

- **`InfoPopup` (KinoPubUI) is the one "show me the rest of this" surface, on every platform** —
  phase 8 of the detail-page plan, with the trigger deliberately changed from the reference app's.
  No round `i` button: `expandsIntoInfoPopup(title:)` makes the *clipped content itself* the
  control. Presentation is the system's per platform — a sheet drawn as a centred panel over a
  scrim on tvOS (where Menu dismisses it for free, and `.presentationBackground(.clear)` is what
  keeps it reading as a popup instead of a pushed page), detents on iPhone/iPad, a panel on macOS.
- **The synopsis now always opens** — every platform, truncated or not. It used to be a dead press
  on tvOS whenever the text happened to fit, and plain unfocusable copy off tvOS: the same
  paragraph behaved two ways for a reason the reader cannot see. The "More" hint still depends on
  truncation, because that is a statement about the text, not about whether the control exists.
- **The About columns open themselves too** (`AboutColumn`, `AboutLegendColumn`) — the same lines at
  reading size, which is the whole point at ten feet. `MediaItemDetailSheet` /
  `MediaItemSheetLayout` are gone; their own doc comment promised "the synopsis, **or a column with
  its lists unclamped**" and only ever delivered the synopsis. **Judge on device:** the columns are
  `Button`s now, so on tvOS they wear `.card`, which argues with `AboutLayoutAppleShape`'s "no card
  behind the columns at all".
- **Hero actions are `.borderedProminent` / `.bordered` with a border shape, and nothing else.**
  Three hand-written `ButtonStyle`s went away: hand-painted capsule and circle plates, hairline
  strokes, `Color.white.opacity(0.22)` fills, black-on-white inversion, `.onHover` state, drop
  shadows, and a `scaleEffect` focus lift with its own spring — a reimplementation of two system
  styles, which on tvOS also meant owning the focus lift, the specular and the press feedback the
  system already ships. `.circle` and `.capsule` are real `ButtonBorderShape`s on tvOS 26 (checked
  in the SDK). What survives is the vocabulary, the icon metrics, and the resume bar — the one part
  with no system equivalent, now drawn with **hierarchical** styles (`.tertiary` / `.primary`) so it
  inverts with the button instead of needing a `forceFocusedColors` flag to guess when the button
  turned white.
- **Trailer is a labelled capsule, first in the row under Play** — not a fifth anonymous circle. The
  circles are all *state* (following / filed / how far in); the trailer is the other thing on the
  page you can watch, and a film glyph among four state glyphs read as one more toggle. The hidden
  "Up from Play opens the fullscreen trailer" gesture is untouched and now arguably redundant —
  left as a product call.
- **Built on tvOS, macOS and iOS. Not run** — the hero and the popup are visual work and the
  simulator is yours.

### One navigation assembly, one tab table, and a lab for the tvOS bar

- **`RouteStack` replaces ten hand-copied stacks.** Every tab used to write the same four lines —
  a `NavigationStack` bound to one of `NavigationState`'s arrays, a `.navigationDestination(for:
  Route.self)` building a `RouteDestination`, and a `.navigationStackActive` gate — and they had
  already drifted: two passed a zoom namespace, eight did not. `RouteStack(tab:zoom:)` now owns all
  four; `appRouteDestinations()` covers the two stacks whose path is local `@State`
  (bookmark-folder tabs, tvOS Settings). Zoom stays **opt-in per stack** because the zoom *source*
  modifier is `#if os(iOS)`-only — publishing a namespace on a stack whose cards never mark a
  source would give the destination a transition with nothing to match.
- **`NavigationState` lost both of its ten-case switches.** `push` and `popToRoot` each carried one
  over the same tabs — two places to forget a tab in. One `routes(for:)` key-path table feeds both,
  plus the new `path(for:)` binding. `.settings` has no shared stack and now says so once.
- **`TabsNavigationView`: four hand-written platform trees → one browse-tab table.** The tabs come
  from `browseTabs` and a `ForEach` (`ForEach` conforms to `TabContent`); each platform only decides
  how a tab labels itself and which utility ends surround it. That drift was already visible — the
  iPad bar's own comment described "glyph · words · glyph" while its code built icon+word chips.
  Badges stay off tvOS: `TabContent.badge` is `@available(tvOS, unavailable)` in the 27.0 SDK
  interface (checked, not assumed).
- **The unrendered profile-avatar fetch is gone.** `TabsNavigationView` downloaded the avatar and
  the user record on every sign-in into `@State` that no branch of its body drew — left over from
  the parked sidebar shell. `SettingsRootView` already loads and caches the avatar for the one
  screen that shows it. Two fewer launch requests, which is the direction
  `docs/archive/plans/2026-08-10-launch-status-and-continuity.md` asks for.
- **Fixed on sight: five Settings diagnostics rows shared one `@FocusState` value.** All bound
  `.focused($focusedItem, equals: .diagnostics)` — the exact ambiguity
  `.claude/skills/tvos-surface/SKILL.md` bans and that cost a misdiagnosed detour on the detail
  page. `SettingsFocusItem.diagnostics` now carries a disambiguating id; the tip stays shared.
- **New DEBUG/tvOS page: Settings → Diagnostics → "Navigation / Focus Lab."** Four shells of the
  same two-tab app, each isolating one variable behind the tab-bar and focus-stranding bugs:
  (A) what ships — stack per tab, SwiftUI rails; (B) one `NavigationStack` outside the `TabView`;
  (C) one `UICollectionView` with the rails as `orthogonalLayoutSectionForMediaItems` sections;
  (D) C plus `setContentScrollView(_:for: .top)`. A HUD reads `isTabBarHidden`, the class+address of
  whatever `contentScrollView(for: .top)` resolved to, and stack depth — because the screen and the
  system disagreeing is the bug, and that is not visible from SwiftUI. Each variant runs in a
  `fullScreenCover`: nested in the real Settings tab it would measure the *app's* tab bar controller
  instead of its own. **Built on all three platforms, not yet run.**

### tvOS wide rails are system media items

- **Every 16:9 horizontal rail now draws with `TVMediaItemContentConfiguration.wideCell()`, laid out
  by `NSCollectionLayoutSection.orthogonalLayoutSectionForMediaItems()`** — new
  `TVUIKitMediaItemRail` in KinoPubUI. The hand-built landscape tile (artwork + gradient legibility
  band + title + meta + progress track, all stacked by hand in `TVUIKitContinueWatchingCell`) is
  gone from the shelf path: text, secondary line, badge, and progress bar are configuration
  properties, so the focus motion, band, badge shape, and bar are all system-owned.
  `MediaPosterShelf` routes landscape cards there; Continue Watching is the first surface on it.
- **Posters stay on `TVPosterView`.** The media-item configuration ships a 16:9
  `wideCellConfiguration` only — there is no 2:3 variant, so `TVUIKitPosterCell` /
  `TVUIKitMediaCollection` remain the poster and vertical-grid path (including landscape *grids*,
  which the orthogonal section cannot express).
- **`text` and `secondaryText` are not two stacked lines under the tile** — measured on device, not
  read off the header: `text` renders centred *below* the artwork, `secondaryText` renders *over* the
  artwork's bottom-leading corner. They are different surfaces; setting both put `secondaryText`
  straight through our own chip in that corner (caught it live — a card's own title, rendered by the
  system in caps, drawn on top of our "▶ 1h 52m"). We use `text` only, and leave `secondaryText` nil.
- **One look, not a set of options.** First pass shipped a knobs struct (scale / progress-on-focus /
  center-glyph / title-on-focus) with an A/B gallery bench to compare them — reasonable for exploring,
  wrong for shipping: no product requirement asked for options, and the result read as "a UI ideas
  page," not a component. `TVUIKitMediaItemRailStyle` is gone; the rail has exactly one behaviour now.
- **Under the tile: the name, always visible, not focus-gated.** A movie's own title, or "S2, E11 ·
  Show" for an episode — built from `overlayLabel` (already formatted "S2, E11" by both History and
  Continue Watching) plus `title`. Earlier this said "state, never the name" and showed a generic
  "Continue" placeholder instead — wrong: the artwork's own baked-in title text is not the same
  surface as the caption below the tile, so putting the real name there is not a duplicate.
- **Inside the artwork: the bar and the runtime are mutually exclusive, both shown immediately —
  never gated by focus.** Went through two readings before landing here. First pass showed "56m left"
  unconditionally beside the glyph; second pass hid all text until focus (bar-only at rest). Landed
  on: `TVUIKitMediaItemStatus.showsRuntime` is true for `.ready`/`.watched`, false for `.inProgress`
  (the bar already says "how far along" — showing both is redundant) and `.upcoming` (nothing is
  known yet). Whichever one applies shows immediately. The glyph (bottom-leading) and the runtime
  (bottom-trailing) are on opposite corners of the same row, not a shared pill — no black background
  behind either; a drop shadow (`applyLegibilityShadow`) carries contrast instead, the same technique
  system text over artwork uses elsewhere. Declined: having the bar itself visually displace the
  glyph/runtime as it fills — the system draws its bar in a separate layer we cannot hook into, so
  that would need custom position math tied to `progress`, exactly the bespoke logic this rail is
  trying to avoid. **No SF Symbol floats over the middle of the tile on focus** — that shipped in the
  first pass and reads as homemade; removed.
- **A top-leading badge carries "Watched" and an upcoming release date** — `TVUIKitMediaItemStatus
  .stateBadgeText` / `.badgeShowsClock`. Unlike the bottom-corner glyph/runtime, this one *does* sit
  on a pill (`badge` in the overlay): it is a badge, the same kind of chrome as the 4K/HDR capability
  badge it replaces for exactly these two states — the corner has room for one, and the state wins
  (`updateConfiguration` suppresses `config.badgeText` whenever `status.stateBadgeText != nil`). The
  system's own badge is text-only (`TVMediaItemContentBadgeProperties` has no icon slot), so the clock
  glyph on an upcoming tile is ours, not the system's — this is the one place in the rail that is
  deliberately custom rather than system-drawn, because the system genuinely cannot do it.
- **Progress is never a series completion ratio.** `TVUIKitMediaItem.status(for:)` returns `.ready`
  for any `isSeries` card with no `video` pinned to it, regardless of what `progress` holds — e.g.
  `WatchingItem.progress` (`LibrarySectionCatalog.card(for:isSeries:)`) is `watched episodes / total`,
  not a resume point, and must never paint a bar even if such a card is ever routed through this rail.
- **`TVMediaItemContentConfiguration.overlayView`** carries what the configuration has no property
  for: a light bottom-up gradient (so the glyph/runtime read over any artwork — this replaces the
  commented-out `TVUIKitBottomInfoBlurView` for this rail specifically), the glyph, the runtime, the
  state badge, and the watched scrim. One view per cell, mutated in place; the configuration is
  rebuilt every state change and would otherwise rebuild the overlay with it.
- **Status drives the glyph** (`TVUIKitMediaItemStatus`): ready/in-progress/watched → play or
  checkmark, unavailable/upcoming → **no glyph at all** — nothing to select. A missing episode is
  signalled by the absent glyph and the caption, not by fading or disabling the tile.
- `TVUIKitMediaItem.badgeText` is one capability token — 4K, else HDR. `MediaCard.badge` deliberately
  does **not** feed it: on Home it carries kino.pub's "+10 new episodes" counter, which is noise in a
  corner chip.
- Sizing is **measured, then scaled**: `orthogonalLayoutSectionForMediaItems()` cannot be resized — it
  exposes neither its group nor its item — so `TVUIKitMediaItemMetrics` probes what it lays out at a
  given width (tile size, gap, vertical padding) with a throwaway collection view and rebuilds an
  equivalent section at a fixed `TVUIKitMediaItemMetrics.scale` (1.18). The system row reads small in
  our shelves; the tile keeps Apple's proportions. The rail reports its height through `sizeThatFits`
  — callers must not pin a `.frame(height:)` on top of it.
- `TVUIKitTileArtwork` draws flat-tint + SF Symbol artwork for tiles with no photograph (genres /
  categories, and the panel shown while a still is in flight). Colour is FNV-hashed from the name so
  a genre keeps its colour across launches — `String.hashValue` is seeded per process.

### TVUIKit gallery

- Rows were cropped because each lockup sat inside a hand-picked SwiftUI `.frame`. A `TVLockupView`
  keeps laying its content out at its own `contentSize` when the outer control is stretched, so the
  content ended up in a corner of an oversized box. Every representable now sets `contentSize` and
  answers `sizeThatFits` from `systemLayoutSizeFitting`; the rows dropped their frames and turned
  off scroll clipping so the focus lift is not sheared at the row edges.
- The media-items section is the shipping `TVUIKitMediaItemRail`, one row per episode state (ready /
  in progress / watched / not on kino.pub / upcoming), plus a genre-tile row on the same component.
  The earlier A/B variants (tile scale, progress-on-focus, centred play glyph) are gone along with
  the style knobs they compared — see above. Monogram cells were sized to the 160pt circle alone,
  which clipped the two labels the system stacks under it.

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
  [detail-page-choreography](docs/archive/plans/detail-page-choreography.md).
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
  [detail-page-choreography](docs/archive/plans/detail-page-choreography.md).
- Fixed one of two writers racing `washProgress` on Up-back-to-hero: `MediaItemHeroView.chromeAlpha`
  read the raw (possibly stale, scroll-overwritten) value directly, unlike
  `MediaItemHeroBackdrop.effectiveWash`'s pre-existing `isHeroOnScreen` guard — so the backdrop
  snapped sharp correctly while the title/button chrome kept re-dimming in step with the still-settling
  scroll. Same guard added to `chromeAlpha`. Confirmed no navigation regression; the visual smoothness
  itself needs eyes-on, not a screenshot, to confirm — see
  [detail-page-choreography](docs/archive/plans/detail-page-choreography.md) phase 4.5.

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
  [apple-native-design](AGENTS.md): always a Dynamic Type text style,
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
  paginated grid cache still open ([ROADMAP](ROADMAP.md#1--foundation-and-ui-stabilization)).

## Earlier

See git history and dated plans under [`docs/archive/plans/`](docs/archive/plans/) /
[`docs/archive/plans/`](docs/archive/plans/) for pre-remediation modernization work.
