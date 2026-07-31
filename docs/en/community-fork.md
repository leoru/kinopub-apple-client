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
| Hand-port features as needed | **Yes** for UI-facing work — steal API/models/services, write our own screens. |

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

- Device streaming profile (`support4k` / `supportHevc` / `supportHdr` / `mixedPlaylist`) + auto-sync
- Vote API (`GET /v1/items/vote`)
- Collections API
- Client-side library facets (KP/IMDb min rating, 4K/HD/AC3) — server ignores those query params
- Keyless Kinopoisk extras via `https://kpapp.link/kpapi/films/<id>/{facts,reviews,staff,images}`
- Actor CDN portraits `https://m.pushbr.com/actors/<md5(ru name)>.jpg`
- Player failure diagnostics / resume thresholds when they beat ours
- Downloads / Sport / TV channels later, as backend slices only

**Leave (their UI / product choices):**

- Their SwiftUI chrome, skeletons, filter sheets, Sport tab layout
- Their “related” shelf (same type + first genre) — we already use real `GET /v1/items/similar`
- Their removal of TMDB — we keep TMDB via our worker for logos / schedules / cast

### How metadata works without keys (why their Mac build “just worked”)

They do **not** ship a Kinopoisk Unofficial API key. Facts, reviews, staff, and stills come from
the public third-party proxy `kpapp.link` (no auth headers; verified 200 on live probes). Actor
headshots come from `m.pushbr.com` keyed by MD5 of the Russian name. Ratings/plot still come from
kino.pub OAuth (`ClientID`/`ClientSecret` in Info.plist — the shared xbmc client, not a Kinopoisk key).

We keep our richer per-user Kinopoisk Unofficial path **and** wire `KinopoiskProxySource` as an
always-on fallback so detail extras work with zero Settings. Proxy is a third-party dependency;
sections stay empty if it dies.

### Port checklist (steal next)

When pulling something new from `community/main`:

1. Prefer `Packages/KinoPubBackend` Request/Model/Response files + a thin `*Service` in
   `KinoPubAppleClient/Services/`.
2. Add / keep mocks so previews compile.
3. Do **not** copy their Views. Wire into our VMs / `MediaRowsView` / detail sections.
4. Note the steal in this file or README API notes.
5. Tick the matching roadmap checkbox when the UI lands.

Already ported into this tree (backend + services; UI mostly still ours to build):

- [x] `VoteRequest` / `VoteData` + `UserActionsService.vote`
- [x] Collections requests/models/responses + `CollectionsService`
- [x] Device settings + `DeviceService.syncCapabilities` (HEVC/4K/HDR/mixedPlaylist)
- [x] `LibraryFilter` client-side facets (KP/IMDb/4K/HD/AC3)
- [x] `KinopoiskExtrasService` (Backend) + `KinopoiskProxySource` (Metadata, always on)
- [x] `ActorImageProvider` (CDN MD5 fallback)
- [x] `FileInfo.dedupedByQuality` for mixed playlists
- [x] Downloads Kit hardening — reject error bodies, delete local file, resume control DB,
      non-discretionary background session, human filenames, speed/ETA
- [x] iOS HLS offline (`HLSAssetDownloadManager` / `HLSDownloadsStore`) + season mp4 queue
- [x] Player prefers local HLS/mp4 when the file exists (identity + episode match)
- [x] TV channels service — `GET /v1/tv` via `VideoContentService.fetchTVChannels` (no Sport UI/EPG yet)
- [ ] Vote UI on the detail page (counts already decode via `communityVotes`)
- [ ] Collections tab / Home rows
- [ ] Filter UI chips for rating/quality
- [ ] Reviews section on the detail page (`TitleMetadata.reviews` is ready)
- [ ] Prefer `ActorImageProvider` when TMDB photo is missing
- [ ] Sport / channels UI + optional external XMLTV EPG (`Services/EPG/*` in community)
- [ ] Downloads list polish (HLS interrupted rows, storage footer) — Kit is ready; keep our chrome
