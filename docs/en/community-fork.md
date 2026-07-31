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
- Their `MediaLibraryStore` as a `ContentStore` replacement
- Wiring `/v1/watching/togglewatchlist` to a checkmark control — **our** checkmark means Mark as Watched

### How metadata works without keys

They do **not** ship a Kinopoisk Unofficial API key. Facts/reviews/staff/stills come from
`kpapp.link`; actor headshots from `m.pushbr.com` (MD5 of Russian name). We keep TMDB + optional
keyed Kinopoisk **and** always-on `KinopoiskProxySource`.

---

## Device identity (why kino.pub showed “unknown”)

kino.pub’s account Devices list uses three notify fields + settings badges:

| Field | Community (raw) | Ours (middle ground) |
| --- | --- | --- |
| `title` | Host / `UIDevice.name` | same |
| `hardware` | machine id (`MacBookPro18,2`) | `MacBook Pro M1 Max, macOS 27` |
| `software` | `macOS Version … (Build …)` | `KinoPub, v0.56 (build)` |
| badges | settings: HLS4 / region / 4K / HEVC / HDR | same via `syncCapabilities` |

Wired on authorize: `registerDeviceIdentity()` then `syncCapabilities()`.
API notes: [`docs/api/device.md`](../api/device.md).
List/remove are on `DeviceService` — Profile chrome is `// DESIGN:` stub only.

---

## Already ported (system)

- [x] Vote / Collections / Device settings + syncCapabilities
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

## System still to port (no UI inventing)

Prefer these next. Land Backend/`*Service` + `// DESIGN:` comments where chrome will sit.

| Priority | Slice | Community path | Notes |
| --- | --- | --- | --- |
| HIGH | `period` on `/v1/items` | `FilterItemsRequest.period` | Server-side hot/popular window (`day`/`week`/`month`/`year`). Add to `LibraryFilter` + `ItemsRequest`. Chip chrome = DESIGN. |
| HIGH | `ResponseCache` | `Client/ResponseCache.swift` + APIClient hook | Opt-in TTL for genres/countries (disk) — **not** personalized shelves (`ContentStore` stays). |
| MEDIUM | `clear-for-season` | `ClearHistoryRequest.Scope.season` | We have item/media clear; season scope missing. Service only until season-rail action is designed. |
| MEDIUM | `NetworkMonitor` | `KinoPubKit/Network/NetworkMonitor.swift` | Debounced `NWPathMonitor`. Banner chrome = DESIGN; don’t copy their tab-lock. |
| MEDIUM | Raise marktimes interval | Player `PlayerTimeObserver` period | Still 10s (same as community). Local store covers resume — can raise once we measure. |
| LOW | Device settings UI | their `Views/Profile/Device/*` | Service ready; Settings list/remove = DESIGN. |
| LOW | Collections Home rows | Collections service already here | Row chrome = DESIGN. |
| SKIP | EPG / Sport UI, Comments, `FilterDataService`, `SectionVisibilityStore`, `WidthThresholdReader`, `WatchingSerial`, wholesale `MediaLibraryStore` | — | Leave alone. |

## DESIGN stubs (do not ship chrome from community)

Agents: add a `// DESIGN:` comment at the call site; **do not** invent buttons.

- [ ] Profile → Devices list / remove (`DeviceService.listDevices` ready)
- [ ] Series watchlist distinct from bookmark folders / Mark as Watched  
      (`actionsService.toggleWatchlist` ready — **not** a checkmark)
- [ ] Collections tab / Home rows
- [ ] Library filter chips (rating/quality already filtered client-side; `period` when ported)
- [ ] Sport / channels + optional XMLTV EPG
- [ ] Downloads list polish (HLS interrupted rows, storage footer)
- [ ] Offline / reachability banner (`NetworkMonitor` when ported)

Detail vote / reviews / actor CDN fallback already landed earlier — leave until a design pass says otherwise; no further UI invention from the community fork.
