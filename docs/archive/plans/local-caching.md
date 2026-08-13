# Plan: local caching (lists + item facts)

> **Archived 2026-08-13.** Survived: §1 (`ContentStore`) shipped for Home/Library rows. The open
> items — per-source TTL, grids joining the store, the image pipeline — are ROADMAP stage 1.


> **Dated implementation history — not living authority.** Continuity rules:
> [data-continuity](../../../AGENTS.md). Open work:
> [01-foundation-continuity](../../../ROADMAP.md).

Date: 2026-07-28. Status: §1 (list cache) shipped for Home/Library rows. §2 (item-facts TTL) not
started.

## Problem

Every tab switch re-fetches everything (`TabsNavigationView.swift:59` alone fires 2 requests on
every switch). No local memory of "we already asked this" — network blips or a second of latency
wipe whatever was on screen. Goal: seamless like a messenger app — show the last known state
instantly, refresh underneath, never blank the screen waiting on network. tvOS can't fully get
there (no durable local storage, `Caches/` is purged when the app isn't running) — accept that and
just use longer TTLs there instead of chasing full parity with iOS/macOS.

Two independent caches, one mechanism (TTL + stale-while-revalidate), reused twice — not three
different systems.

## 1. List cache — `ContentStore`

Owns rows (Home shortcuts, Library watchlist/history/folders). Views still own their `@Published
rows: [MediaRow]` (kept as `ObservableObject`, not `@Observable` — see precondition note below) but
that array is now assembled by reading the store, not by owning fetched data directly.

- [x] `@MainActor final class ContentStore` —
      [KinoPubAppleClient/Services/Cache/ContentStore.swift](../../../KinoPubAppleClient/Services/Cache/ContentStore.swift).
      Plain class, not `@Observable` yet (see precondition below); callers read `cards(_:)`
      synchronously and re-assemble their own `@Published` array after `refresh`/`refreshIfStale`.
- [x] `RowKey` — [.../Cache/RowKey.swift](../../../KinoPubAppleClient/Services/Cache/RowKey.swift):
      `.continueWatching`, `.shortcut(MediaShortcut, MediaType)`, `.watchlist`, `.history`,
      `.folder(Int)`. **Scope note:** `RowState` ended up as `{ cards, fetchedAt }` — no
      `pagination`/`isComplete`. Home/Library rows are fixed-size summaries with no "load more";
      pagination belongs to the Movies/Series/Search grids (`MediaCatalog`/`LibraryCatalog`), which
      this pass didn't touch — tracked below as follow-up work, not silently dropped.
- [x] Disk snapshot — [.../Cache/RowSnapshotStore.swift](../../../KinoPubAppleClient/Services/Cache/RowSnapshotStore.swift),
      one JSON file in `Caches/KinoPubContentStore/rows.json` (all rows, not file-per-key like the
      original sketch — simpler, and the whole set is a few KB). Loaded synchronously in
      `ContentStore.init`.
- [x] TTLs exactly as planned, in `RowKey.ttl`: `continueWatching`/`history` 60s, `watchlist` 120s,
      `shortcut`/`folder` 10–15min.
- [x] `refreshIfStale(_:fetch:)` + `refresh(_:fetch:)`, dedup via `inFlight: [RowKey: Task]`.
- [x] **Local writes are authoritative.** `setCards`/`removeCard` stamp `fetchedAt = now`.
      `HomeCatalog.hide`/`toggleWatched` remove the card from the store optimistically before the
      network call even starts.
- [x] `invalidate(family:)` — `RowKey.Family` enum (`.watch` / `.catalog` / `.bookmarks`), not raw
      strings. Wired into `MediaItemModel`'s toggle-watched/clear-history/toggle-bookmark success
      paths, so a mutation on the detail page is reflected next time Home/Library reads the store,
      instead of waiting out the TTL.
- [x] **Stale beats blank, verified per producer.** `HomeCatalog.fetchContinueWatchingCards`/
      `fetchShortcutCards` and `PersonalLibraryCatalog`'s three producers all `throw` on failure
      rather than returning `[]` — `ContentStore.performFetch`'s catch block leaves the cached row
      untouched on any failure. (Continue-watching specifically: its four sub-fetches each swallow
      their own errors via `try?` for partial-source resilience; the producer only throws when
      *all four* come back nil, so a single dead endpoint still shows the other three.)
- [x] Home (`HomeCatalog`) and Library (`PersonalLibraryCatalog`) rewired end to end.
- [x] Sidebar folder/watchlist-badge sync in `TabsNavigationView` — was firing 2 requests on
      **every** tab switch unconditionally; now gated by a 120s `sidebarSyncedAt` timestamp. Kept
      as a local debounce rather than routed through `ContentStore` (`[Bookmark]`/`Int` don't fit
      the store's `[MediaCard]`-shaped rows) — separate small fix, same principle.
- [x] `MediaCard` made `Codable` (was `Identifiable, Hashable`) so rows can round-trip through JSON.
- [ ] **Not done: `@Observable` migration.** `ContentStore` itself could be `@Observable` with no
      cost (new type, no legacy dependents), but `HomeCatalog`/`PersonalLibraryCatalog` reading it
      are still `ObservableObject`, so nothing downstream gets granular per-row invalidation yet —
      a card update still republishes the whole `rows` array. Correctness of caching (fewer
      requests, instant paint, optimistic mutation) does **not** depend on this; render-performance
      granularity does. Tracked separately, not blocking.
- [ ] **Not done: `MediaCatalog`/`LibraryCatalog` (Movies/Series/Search grids).** These are
      paginated, unlike the Home/Library summary rows — would need `RowState.pagination` /
      `isComplete` back, matching the original sketch. Same `ContentStore`, bigger `RowState`.

## 2. Item-facts cache — extend `MetadataCache`

Owns per-title profile data: kino.pub item details, TMDB (credits/images/videos/keywords),
Kinopoisk Unofficial (awards/facts/RU cast). Keyed by request, same shape it already has in
[`Packages/KinoPubMetadata/Sources/KinoPubMetadata/Core/MetadataCache.swift`](../../../Packages/KinoPubMetadata/Sources/KinoPubMetadata/Core/MetadataCache.swift)
— extend it, don't build a second thing next to it.

- [ ] Per-source TTL instead of one TTL passed ad hoc at call sites:
  - kino.pub item details — no cache headers on this endpoint (confirmed,
    [docs/archive/research-2026-07/09-metadata-integrations.md §1.8](../research-2026-07/09-metadata-integrations.md)) →
    our own TTL, hours.
  - TMDB / Kinopoisk via the Cloudflare proxy — already edge-cached 6h
    ([workers/tmdb-proxy/README.md](../../../workers/tmdb-proxy/README.md)) → safe to keep locally
    much longer, days–weeks (awards/bio/logos don't change).
- [ ] On stale read: return what's cached **and** kick a background refresh — never block the
      detail page on network. Same stale-while-revalidate shape as `ContentStore`, just longer
      windows.
- [ ] No separate "render hints" computation step — the profile record already carries whatever
      fields the source sent (logo path, backdrop, description, dominant color if computed once at
      fetch time). Card layout reads presence/absence of those fields directly; nothing extra to
      maintain.
- [ ] tvOS: same code path, just lean on the longer TTLs — `Caches/` gets swept, don't fight it
      with a durable-storage workaround.

## Explicitly deferred

- [ ] **Image pipeline** (own `NSCache` + disk + downsample layer). Parked — `AsyncImage` gets
      native HTTP caching in **27** (confirmed, [docs/archive/research-2026-07/07-ui-components-a11y.md](../research-2026-07/07-ui-components-a11y.md)),
      and 27 is plausible on our own devices. Revisit once that's confirmed working on-device;
      don't build the custom loader speculatively.
- [ ] Offline kino.pub catalog index (`tools/kinopub-snapshot`, `tools/kinopoisk-metadata`) —
      separate concern (coverage/recommendations, not response caching), out of scope for this doc.

## Order of work

1. ~~`ContentStore` (§1) — fixes the daily annoyance (tab switch amnesia).~~ **Shipped** for
   Home/Library rows.
2. `MediaCatalog`/`LibraryCatalog` grids onto the same `ContentStore` (needs pagination back on
   `RowState`).
3. `@Observable` migration where `ContentStore`-backed views need it.
4. `MetadataCache` TTL-by-source + background refresh (§2).
5. Revisit image pipeline once 27 caching behavior is confirmed on-device.
