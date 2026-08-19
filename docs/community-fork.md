# Tracking [dungeon-master-xx/kinopub-apple-client](https://github.com/dungeon-master-xx/kinopub-apple-client)

We forked [leoru/kinopub-apple-client](https://github.com/leoru/kinopub-apple-client). So did they.
Both trees share an old common ancestor (`d5cab98`), then diverge hard: ~100 of our commits
(tvOS-first UI, Liquid Glass, `KinoPubMetadata`, workers) vs ~200 of theirs (iOS/macOS features,
AltStore, Sport, richer device/download stack).

## Strategy: remote + manual port — not rebase

| Approach | Verdict |
| --- | --- |
| `git rebase` / merge `community/main` onto us | **No.** Mutual non-ancestors, opposing UI, opposing metadata strategies. Conflict storm with no product win. |
| Add a second remote and cherry-pick / copy technical slices | **Yes.** This is what we do. |
| Hand-port features as needed | **Yes** for system/API work. **UI chrome is DESIGN TBD** — leave `// DESIGN:` comments at call sites; do not invent buttons/layouts from their Views. |

### Remotes

```bash
git remote add community https://github.com/dungeon-master-xx/kinopub-apple-client.git
git fetch community
git log --oneline community/main -n 20
```

`community` is already added in agents' workspaces when they fetch it. It is **not** a push
target — we never push our UI there. Use it to read, cherry-pick isolated backend commits, or
`git show community/main:path/to/File.swift`.

### What we take / leave

**Take (technical / system):**

- Device identity (`POST /v1/device/notify`) + streaming profile (HEVC/4K/HDR/`mixedPlaylist`)
- Vote / Collections / watchlist / bookmark-folder APIs
- Client-side library facets (KP/IMDb min rating, 4K/HD/AC3)
- Keyless Kinopoisk extras + actor CDN portraits
- Local watch-progress + `WatchProgress` classifier
- Stream quality cap via `preferredMaximumResolution`
- Downloads Kit hardening / iOS HLS offline (backend + Kit; keep our chrome)
- TV channels service (no Sport UI yet)

**Leave (their UI / product choices):**

- Their SwiftUI chrome, skeletons, filter sheets, Sport tab, Devices settings screens
- Their “related” shelf — we use `GET /v1/items/similar`
- Their removal of TMDB — we keep the worker
- Their `MediaLibraryStore` as a **`ContentStore` replacement** (rows stay ours). The
  per-item optimistic half — watchlist / watched / votes / download façade — **is** taken
- Wiring `/v1/watching/togglewatchlist` to a checkmark control — **our** checkmark means Mark as Watched

### How metadata works without keys

They do **not** ship a Kinopoisk Unofficial API key. Facts/reviews/staff/stills come from
`kpapp.link`; actor headshots from `m.pushbr.com` (MD5 of Russian name). We keep TMDB + optional
keyed Kinopoisk **and** always-on `KinopoiskProxySource`.

---

## Device identity (why kino.pub showed “unknown”)

kino.pub’s account Devices list uses three notify fields + settings badges:

| Field | Community (raw) | Ours (system-derived, no model table) |
| --- | --- | --- |
| `title` | Host / `UIDevice.name` | `DeviceIdentity.deviceName` — the system's name, bidi marks stripped |
| `hardware` | machine id (`MacBookPro18,2`) | `Mac (MacBookPro18,2, Apple M1 Max)` / `iPhone (iPhone17,1)` |
| `software` | `macOS Version … (Build …)` | `macOS 27.0, KinoPub v1.0 (1)` — OS first, per the API docs |
| badges | settings: HLS4 / region / 4K / HEVC / HDR | same, via `syncDeviceProfile(activated:)` |

Nothing here is looked up in a table of model identifiers: an unknown device must still read
correctly, so every part comes from the OS at runtime and the raw identifier rides along in
parentheses. Two traps: on macOS `uname` returns the *architecture* (the model is `sysctl hw.model`),
and in a Simulator both are the host Mac's — `SIMULATOR_MODEL_IDENTIFIER` is the simulated device.

Wired on **activation**: `syncDeviceProfile(activated: true)`. A launch that only revived a Keychain
token sends nothing unless the payload changed — `DeviceProfileRegistry` holds the fingerprint of
the last successful registration and is cleared on logout. (kino.pub's docs suggest notifying every
launch; we don't, because the capability write would keep overwriting a profile edited in Settings.)

Body-POST parameters only land if the request says `Content-Type: application/json` — an unlabelled
JSON body is treated as a form, parses to nothing, and still answers `{"status":200}`. `RequestBuilder`
sets it; that was the bug behind "unknown / unknown / unknown".
API notes: [`docs/archive/kinoapi-v1.3-ru/device.md`](archive/kinoapi-v1.3-ru/device.md) (prefer [kinoapi.com](https://kinoapi.com)).
List/remove are on `DeviceService` — Profile chrome is `// DESIGN:` stub only.

---

## Already ported (system)

- [x] Vote / Collections / Device settings + `syncDeviceProfile(activated:)`
- [x] Device notify identity (`DeviceIdentity` + `DeviceNotifyRequest` body POST)
- [x] Device list/remove service APIs (`ManagedDevice`, no Settings UI yet)
- [x] `LibraryFilter` client facets
- [x] Kinopoisk proxy + `ActorImageProvider`
- [x] `FileInfo.dedupedByQuality`
- [x] Downloads Kit hardening + iOS HLS offline + season queue
- [x] Player prefers local HLS/mp4 when present
- [x] TV channels `GET /v1/tv`
- [x] Bookmark toggle body POST + null-tolerant `EmptyResponseData`
- [x] `WatchProgress` + `LocalWatchProgressStore` + player/Home wiring
- [x] `StreamQuality` + Settings picker
- [x] `ToggleWatchlistRequest` + folder create/remove **service** APIs
- [x] `CatalogPeriod` / `period` on `/v1/items` (`LibraryFilter` + `ItemsRequest`)
- [x] `ResponseCache` for genres/countries (year TTL; **not** cleared on logout)
- [x] `clear-for-season` history API
- [x] `NetworkMonitor` (`KinoPubKit`) + app `environmentObject` (banner = DESIGN)
- [x] Raise marktimes — local resume ~10s, server `marktime` ~30s (was gated at >60s)
- [x] `MediaLibraryStore` — per-item optimistic library (watchlist / watched / votes /
      download façade). Does **not** replace `ContentStore` or the bookmark stores.

## Comparison snapshot (2026-08-18)

A literal `git merge community/main` is still a bad idea: ~73 files changed in both,
almost all Views / pbxproj / UI packages, plus Sport/EPG/AltStore we do not want.
This branch ports the architecture that was actually missing, not their renderer.

| Slice | Community | Ours after this branch |
| --- | --- | --- |
| Home/Library row cache | none (refetch on appear) | **`ContentStore` + disk snapshots** — keep |
| Per-item optimistic library | `MediaLibraryStore` | **ported** as façade; bookmarks stay on our two stores |
| Continue Watching | hide finished + `WatchProgress` | **already ahead** (`ContinueWatchingEpisode` / order / local merge) |
| Lazy lists | `LazyHStack`/`LazyVStack` in SwiftUI shelves | **already** in `MediaPosterShelf` / `MediaRowsView` / grids; tvOS is UIKit collections |
| Glass | iOS 26 `glassEffect` experiments | **ours** via `kinoGlass` — do not take theirs |
| Genres/countries | disk cache | year TTL, **not** cleared on logout |
| API / metadata | kpapp.link only, no TMDB | **ours is ahead** (`KinoPubMetadata`, identity map, workers) |
| Sport / EPG / Comments / `FilterDataService` | present | **leave** (`FilterDataService` is just genres/countries — already on `VideoContentService` + year TTL) |

## Continue Watching — why ours is ahead, and what would actually make it better

Community Home builds the row from **`/v1/history` only** (first 10 unique titles), then **N detail fetches**, drops `WatchProgress.isFinished`, merges local progress, sorts by recency. That is the 2026-06 "hide finished + WatchProgress" commit.

Ours already does that, then extra:

| Rule | Where |
| --- | --- |
| Four sources, independently degrading | `/v1/watching/movies` + `/serials` + `?subscribed=1` + `/history` — all-fail keeps the cached row |
| Watchlist with `new` badges is in the pool | `ContinueWatchingOrder.mergePool` |
| Buckets, not a flat recency list | recently started (7d) → new episodes on watchlist → rest of watchlist → unfinished |
| Last history row is **not** the next episode | `ContinueWatchingEpisode` + `MediaItem.primaryEpisode` (the same answer the Play button uses) |
| Finished series dropped | `playbackAction == .playAgain` → no card |
| Progress bar only while mid-episode | a fresh next episode must not inherit the previous runtime |

What would still make **our** row better (none of this is in their services):

1. **~~Invalidate `.watch` when playback ends~~** — rejected: that would refetch every Home
   watch row. Local resume overlays the Continue Watching *section* at paint time
   (`ContinueWatchingLocalOverlay`); the player writes a finished tombstone instead of
   clearing. Home TTL stays the server snapshot.
2. **Episode rail leading card = resume / next-unwatched** — already the Home/Play answer; the seasons rail still leads chronological. ROADMAP §1.
3. **~~Remember series details with the row~~** — done: a card that already carries S/E is
   trusted on refresh; details are fetched only for *new* series ids (still capped at 12).
4. **Raise or drop `seriesDetailLimit` (12)** — past that cap, titles with no cached S/E still fall back to history counters and can still offer the wrong episode.

Do not port their `WatchingSerial` — it is the same JSON as our `WatchingItem`. Do not port `PlayerContinueWatchingView` (their SwiftUI chrome).

## Service-by-service leftover (2026-08-18, method level)

Their `Services/` folder looks bigger. Most of it is already here under another name. What is actually left:

| Their type | Verdict | Why |
| --- | --- | --- |
| `FilterDataService` | **don't port** | Two methods: genres + countries. We have them on `VideoContentService` with disk TTL. |
| `EPGService` / `EPGProgram` | **leave** | Sport UI. |
| `SectionVisibilityStore` | **already ours** | Settings › Sections. |
| `WatchingSerial` | **don't port** | Duplicate of `WatchingItem`. |
| `GetItemFoldersRequest` / `foldersContaining` | **don't port** | Detail must not fetch this; membership is on the item + `BookmarkMembershipStore`. |
| `CommentsRequest` | **leave** | Comments UI. |
| `filter(MediaItemsFilter)` / `FilterItemsRequest` extra keys | **maybe later** | Age / language / translation / quality / conditions are **ignored by `/v1/items`** (their own comment). Client-side facets we already have on `LibraryFilter`. `cast`/`director`/`period`/`genre` we already send via `ItemsRequest`. |
| `search(..., field:)` | **don't port** | They themselves say `?cast=`/`director=` on `/v1/items` is the reliable path — that's `LibraryFilter.person`. |
| `fetch(..., forceRefresh:)` + first-page **memory TTL 120s** on catalog | **real leftover** | They cache Home/catalog page 1 in `ResponseCache`. We cache **rows** in `ContentStore` instead. ROADMAP already wants paginated Movies/Series/Search **into `ContentStore`**, not a second HTTP cache on `ItemsRequest`. |
| `itemsByPerson` | **already ours** | `fetchItems(filter: LibraryFilter(person:))`. |
| `fetchComments` | **leave** | |
| `toggleBookmark` on `UserActionsService` | **already ours** | On `VideoContentService`. |
| `GetWatchingDataRequest` | **already ours** | `fetchWatchMark`. |
| Device `registerDeviceName` + `syncCapabilities` | **already ours** | Combined as `syncDeviceProfile(activated:)`. |
| Collections | **already ours** | Plus `fetchCollections(forItem:)` which they don't have. |
| `MediaLinksResolver` / `nolinks` | **ours only** | They always fetch details with links. |

**Nothing in their service layer is a hidden fifth cache we missed**, besides the catalog page-1 HTTP TTL — and our `ContentStore` is the place that job belongs.


## System still to port (no UI inventing)

Prefer these next. Land Backend/`*Service` + `// DESIGN:` comments where chrome will sit.

| Priority | Slice | Status | Notes |
| --- | --- | --- | --- |
| HIGH | `period` on `/v1/items` | **done** | `CatalogPeriod` on `LibraryFilter` → `ItemsRequest`. Chip = DESIGN in `LibraryFiltersBar`. |
| HIGH | `ResponseCache` | **done** | Genres/countries disk **365d**; keep across logout (iron lists). Not catalog pages. Optional: bake into client later. |
| HIGH | `clear-for-season` | **done** | `ClearHistoryForSeasonRequest` + `UserActionsService.clearHistoryForSeason`. Rail chrome = DESIGN. |
| MEDIUM | `NetworkMonitor` | **done** | Debounced `NWPathMonitor` in Kit; injected at app root. Banner = DESIGN in `TabsNavigationView`. |
| MEDIUM | Raise marktimes interval | **done** | Local `LocalWatchProgressStore` every ~10s; server every ~30s; end-of-play still final mark. |
| LOW | Device settings UI | service ready | Settings list/remove = DESIGN. |
| LOW | Collections Home rows | service ready | Row chrome = DESIGN. |
| LOW | Card download status from `MediaLibraryStore` | façade ready | Badge overlay = DESIGN; do not invent a second card. |
| OURS | Local CW overlay, no Home TTL reset | **done** | Paint-time overlay from `LocalWatchProgressStore`; `markFinished` keeps a tombstone. Cached S/E skips the 12-details refresh. Not a community port. |
| SKIP | EPG / Sport UI, Comments, `FilterDataService`, `WatchingSerial`, `MediaLibraryStore` as a ContentStore replacement, `GetItemFolders` | — | Duplicate or product-rejected. |
| SKIP | EPG / Sport UI, Comments, `FilterDataService`, `SectionVisibilityStore`, `WidthThresholdReader`, `WatchingSerial`, `MediaLibraryStore` as a ContentStore replacement | — | Leave alone. |

## DESIGN stubs (do not ship chrome from community)

Agents: add a `// DESIGN:` comment at the call site; **do not** invent buttons.

- [ ] Profile → Devices list / remove (`DeviceService.listDevices` ready)
- [ ] Series watchlist distinct from bookmark folders / Mark as Watched  
      (`actionsService.toggleWatchlist` ready — **not** a checkmark)
- [ ] Collections tab / Home rows
- [ ] Library filter chips (rating/quality client-side; `CatalogPeriod` ready to send)
- [ ] Season-rail clear progress (`clearHistoryForSeason` ready)
- [ ] Sport / channels + optional XMLTV EPG
- [ ] Downloads list polish (HLS interrupted rows, storage footer)
- [ ] Offline / reachability banner (`NetworkMonitor` wired; chrome TBD)
- [ ] Card / detail download status from `MediaLibraryStore.downloadStatus` (façade ready)

Detail vote / reviews / actor CDN fallback already landed earlier — leave until a design pass says otherwise; no further UI invention from the community fork.
