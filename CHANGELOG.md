# Changelog

Notable shipped changes and implementation facts future agents need. Trivial copy/token churn does
not belong here. Detail checklists live under [`docs/en/features/`](docs/en/features/).

## Unreleased

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
