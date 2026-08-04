# 01 — Foundation and UI stabilization

**Status:** In progress  
**Goal:** Local metadata/image continuity, stable navigation/focus/materials, and finish-or-gate
current auxiliary work so the app feels instant and native.

## Accepted behavior

- Stale-while-revalidate for Home/Library summary rows (`ContentStore`).
- Contained Home banner shelf; private `variableBlur` on static art; system material under sidebar.
- Unified `Route` / `RouteDestination`; single `PlaybackSession`.
- Continuity beats blank: card→detail carries known item + artwork when available.
- Exact skeletons only on true cold loads; Search empty poster grid allowed for focus landing.

## Checklist

- [x] Home/Library list cache + disk snapshots (`ContentStore` / `RowSnapshotStore`)
- [x] Banner shelf + delete Netflix focus-preview path
- [x] Home banner gated by `FeatureFlags.homeBannerEnabled` (off by default; off skips sampling + artwork loads)
- [x] Private `variableBlur` replaces Metal progressive blur
- [x] Unified routes + zoom transitions (iOS/tvOS)
- [x] App-scoped `PlaybackSession`
- [ ] Paginated Movies/Series/Search grids participate in the same store model
- [ ] Item-facts TTL cache extension (`MetadataCache`) for kino.pub details + enrichment
- [ ] Shared image pipeline (dedupe, disk, prefetch, palette) — evaluate Nuke vs finish in-house
- [ ] Card→detail handoff always seeds hero from known artwork (no bare background when card had art)
- [ ] Finish or feature-gate incomplete auxiliary chrome from the modernization pass
- [ ] High-risk surfaces marked validation-pending until Device Hub / macOS visual checks

### Atoms and duplication

- [ ] One `AsyncImage` atom instead of ~15 call sites
- [ ] De-duplicate the two initials-avatar implementations into one atom
- [ ] Fold the episode card into the shared caption + progress structure — behavioural identity
  (same focus animation, caption reveal, progress semantics, watched treatment) is the acceptance
  criterion; only aspect and filled slots may differ
- [ ] Collapse the 16 custom `ButtonStyle` types (separate pass)
- [ ] `MediaItemInfoColumns` → `Grid` / `GridRow` + `gridColumnAlignment(.leading)`

### Accessibility and type

- [ ] `MediaCardView` gets an `accessibilityLabel`
- [ ] `RatingBadgeView` encodes tier **only** by colour — add a non-colour differentiator
- [ ] Replace remaining `.system(size:)` calls with text styles
- [ ] `@ScaledMetric` on every square / hairline dimension (portraits, circular buttons, tab icons)

### Focus, navigation, chrome

- [ ] `MediaItemHeroView` — four buttons share `.focused($focus, equals: .heroOther)`
- [ ] `MediaItemView` two-slide `.offset(y:)` + `.clipped()` "slideshow"
- [ ] `TabsNavigationView` — 630 lines across three near-identical platform trees
- [ ] Detail hero height → `containerRelativeFrame(.vertical)` instead of hard-coded values
- [ ] Card → detail transition: prefer the default / system morph before anything custom
- [ ] tvOS tab background via `containerBackground(for: .tabView)` where useful
- [ ] `LibraryFiltersBar` / `MainView` material cleanups — system glass only where it matches
  scroll / nav chrome, through `kinoGlass`
- [ ] Apply the `variableBlur` helper on detail / Home hero and banner overlays
- [ ] Bring poster overlays back on tvOS behind an explicit `.hoverEffect(.highlight)`
- [ ] Banner polish: page dots / L-R affordances only if it becomes a real carousel

**Known ceiling, so nobody plans around it:** `TabViewCustomization` limits are documented in the
plan — check there before designing sidebar customization.

## Folded from plans

Open items from [`docs/en/plans/local-caching.md`](../plans/local-caching.md) §2 and grid pagination
belong here — not in README minutiae. The UI items above were moved out of
[`modernization.md`](../plans/modernization.md) when that plan was closed to pure history; the plan
still holds the detailed rationale and file:line references for each.

## Validation

- [ ] Tab return shows cached rows without blank flash
- [ ] macOS sidebar bleed / banner aspect / wide artwork load
- [ ] tvOS focus on banner → first shelf without dead space
