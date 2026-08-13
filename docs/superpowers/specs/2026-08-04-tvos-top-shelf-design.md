# tvOS Top Shelf — Design

**Date:** 2026-08-04  
**Status:** Awaiting user review of this spec  

**Roadmap:** [`ROADMAP.md`](../../../ROADMAP.md)  
**Platform notes:** [`.claude/skills/tvos-surface/SKILL.md`](../../../.claude/skills/tvos-surface/SKILL.md)  
**Research (evidence, not law):** [`docs/archive/research-2026-07/06-tvos-focus.md`](../../archive/research-2026-07/06-tvos-focus.md)

## Goal

Ship a tvOS Top Shelf extension that shows Continue Watching from a main-app-written App Group cache. The extension never performs network work. This is a deliberate exception to the repo’s one-app-target rule (Top Shelf cannot live in the main target).

## Decisions (v1)

| Topic | Choice |
| --- | --- |
| Content source | Continue Watching only (`ContentStore` / `.continueWatching`) |
| Presentation | `TVTopShelfCarouselContent(style: .details)` |
| Trailer / `previewVideoURL` | Omit — CW cards have no trailer URL today |
| Tap / Play / More Info | Both actions open detail: `kinopub://item/{id}` → `Route.detailsById` |
| Empty CW | Clear cache; extension returns `nil` (static app icon) |
| Wiring | Thin shared cache + extension; hooks in `ContentStore` |
| Max items | 8 |

## Architecture

```
Home / CW mutations
        │
        ▼
  ContentStore (.continueWatching)
        │  map MediaCard → TopShelfSnapshot
        ▼
  TopShelfCache  ──UserDefaults(suiteName: group.com.soda.kinopub)──►  KinoPubTopShelf
        │                                                              ContentProvider
        └── TVTopShelfContentProvider.topShelfContentDidChange()       (read-only)
                                                                              │
                                                                              ▼
                                                                   TVTopShelfCarouselContent
                                                                              │
                                                                   kinopub://item/{id}
                                                                              │
                                                                              ▼
                                                         App onOpenURL → Route.detailsById
```

### Targets & packaging

- **Main app:** existing `com.soda.kinopub` multiplatform target. App Group entitlement added (harmless on non-tvOS; write path `#if os(tvOS)`).
- **Extension:** new `KinoPubTopShelf` target, bundle id `com.soda.kinopub.topshelf`, tvOS-only, `NSExtensionPointIdentifier = com.apple.tv-top-shelf`, principal class = content provider. Embedded in the app for Apple TV builds only.

### App Group

- Identifier: `group.com.soda.kinopub`
- Storage: `UserDefaults(suiteName:)` JSON for a small snapshot array (Rivulet-style; prefer over file I/O in the extension).
- Key: fixed string e.g. `continueWatchingItems`.

## Components

### `TopShelfSnapshot` (Codable)

Fields written in v1 (all already available on Continue Watching `MediaCard` — no extra fetches):

- `id: Int`
- `title: String`
- `imageURL: String` (landscape / backdrop preferred, else poster)
- `progress: Double?`, `season: Int?`, `episode: Int?`, `isInWatchlist: Bool` — stored for the deferred Play-resume path; unused by the extension in v1

No `trailerURL` in v1.

### `TopShelfCache` (main app, `#if os(tvOS)`)

- `write(_ items: [TopShelfSnapshot])` — prefix 8, encode, store.
- `clear()` — remove key / write empty.
- Called only from ContentStore hooks (and optionally once after init load if CW is already on disk).

### `ContentStore` hooks

After any mutation that changes `.continueWatching` cards that should be visible on the shelf:

1. Successful `performFetch` for `.continueWatching`
2. `setCards(..., for: .continueWatching)`
3. `removeCard(..., from: .continueWatching)`

Also: after `init` disk load, if `.continueWatching` has cards, write once so a cold launch without a refresh still populates the shelf.

Failed refresh: **do not** overwrite the shelf cache (same continuity rule as the row itself).

Empty successful CW list: `clear()` + `topShelfContentDidChange()`.

Ping: `TVTopShelfContentProvider.topShelfContentDidChange()` after every write/clear (tvOS only; import TVServices in that helper).

### Extension `ContentProvider`

- Subclass `TVTopShelfContentProvider`.
- Implement `loadTopShelfContent` (completion-handler API from TVServices; use Swift async wrapper only if the installed SDK exposes one — verify against AppleTVOS27 SDK).
- Read `TopShelfCache` (duplicate small read helper in the extension target; do **not** link the whole app or network stack).
- Build carousel items:
  - `identifier` = stringified id
  - `title` from snapshot
  - image URL for 1x/2x traits (same URL is fine)
  - `playAction` + `displayAction` both `TVTopShelfAction(url: kinopub://item/{id})`
- Empty / decode failure → call completion with `nil`.

### Deep linking

- Register URL scheme `kinopub` in the main app Info / target URL types.
- `WindowGroup` / root `.onOpenURL`: parse `kinopub://item/{id}` → `navigationState.selectedTab = .home`, append `Route.detailsById(id)` to `mainRoutes` (replace or push one detail — avoid stacking duplicates of the same id if cheap).
- No other schemes in v1.

## Deferred best-practice follow-ups (comment in code; do not implement now)

### 1. Play action → resume / new episode

**Preferred later behavior:** `playAction` should start playback when the item is in-progress, or is a watchlist title with a new episode; `displayAction` stays on detail.

**What needs to exist:**

- Snapshot fields already useful: `progress`, `season`, `episode`, `isInWatchlist` (and eventually a “has new episodes” flag if not implied).
- A play deep link, e.g. `kinopub://play/{id}?season=&episode=` (exact shape TBD).
- One navigation entry that can build/resume a `PlayableItem` without forcing a blank detail round-trip when metadata is already known.
- Wire `playAction` to that URL; keep `displayAction` on `kinopub://item/{id}`.

### 2. Empty shelf → Featured / Popular fallback

**Preferred later behavior:** when Continue Watching is empty, show a small Featured/Popular set instead of the static icon.

**What needs to exist:**

- A main-app source row (featured / popular / banner pool) that already refreshes without extension network calls.
- Cache schema tagged by kind, e.g. `kind: continueWatching | featured`, or separate keys with extension preference order: CW if non-empty, else featured.
- Write path on that row’s refresh + clear/replace rules when CW becomes non-empty again.
- Still: extension read-only; no network inside the extension.

### 3. `previewVideoURL`

Add only when the main app can cheaply attach a trailer URL to the snapshot (e.g. already-known from detail cache). Never fetch trailers inside the extension.

## Out of scope

- Light theme, TVUIKit lockups, multi-user `TVUserManager`, layered `.lcr` artwork.
- Editing feature docs / README beyond what implementation planning may tick in stage 05 after validation.
- Third-party analytics.

## Validation

1. `xcodebuild` for `appletvsimulator`: main + extension compile; extension embedded.
2. Non-empty CW cache → carousel visible on simulator Apple TV home screen.
3. Empty CW → static icon.
4. Select item → app opens to that title’s detail.
5. CW remove/refresh → shelf updates after `topShelfContentDidChange()` (simulator may need home re-entry).

Simulator Top Shelf / focus is provisional per `AGENTS.md`; treat on-device as stronger confirmation when available.

## API check (SDK)

Verified against `AppleTVOS27.0.sdk` TVServices headers: `TVTopShelfContentProvider`, `TVTopShelfCarouselContent`, `TVTopShelfCarouselItem` (`previewVideoURL`), `TVTopShelfAction`, `topShelfContentDidChange` remain current. Prefer carousel over sectioned content because trailers / preview video remain the intended long-term fit even though v1 omits them.
