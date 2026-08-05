# Changelog

Notable shipped changes and implementation facts future agents need. Trivial copy/token churn does
not belong here. Detail checklists live under [`docs/en/features/`](docs/en/features/).

## Unreleased

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
