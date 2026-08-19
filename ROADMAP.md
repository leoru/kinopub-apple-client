# Roadmap

Ordered product stages, their accepted behavior, and what is still open. Rules live in
[AGENTS.md](AGENTS.md); this file is *what we are building*, not *how*.

Tick a box here when something lands. Dated narrative belongs in `docs/archive/`, not here.

| # | Stage | Status |
| --- | --- | --- |
| 1 | [Foundation and UI stabilization](#1--foundation-and-ui-stabilization) | In progress |
| 2 | [Access and app shell](#2--access-and-app-shell) | In progress |
| 3 | [Library and History](#3--library-and-history) | Partial (macOS shell landed) |
| 4 | [KinoPub catalog completeness](#4--kinopub-catalog-completeness) | Partial |
| 5 | [Platform completeness and appearance](#5--platform-completeness-and-appearance) | Not started |
| 6 | [Discovery and enrichment](#6--discovery-and-enrichment) | Partial |
| 7 | [Playback conveniences](#7--playback-conveniences) | P0 mostly done |
| 8 | [Advanced subtitles](#8--advanced-subtitles) | Parked, deliberately last |

---

## 1 — Foundation and UI stabilization

**Goal:** local continuity, stable navigation/focus/materials, and finish-or-gate the auxiliary
work so the app feels instant and native.

**Accepted:** stale-while-revalidate for Home/Library rows (`ContentStore`); card → detail carries
the known item and artwork; exact skeletons only on true cold loads (Search may show an empty poster
grid so the remote has a focus landing zone); contained Home banner shelf; unified `Route` /
`RouteDestination`; one `PlaybackSession`.

- [x] Home/Library list cache + disk snapshots (`ContentStore` / `RowSnapshotStore`)
- [x] Per-item optimistic library (`MediaLibraryStore`: watchlist / watched / votes / download façade)
- [x] Continue Watching paints from local resume (`LocalWatchProgressStore`) without
      invalidating Home TTL. Player `markFinished` writes a finished tombstone (hide a
      film / step a series); the row's cached S/E skips the 12-details refresh. Past
      that cap, new series still fall back to counters.
- [x] Banner shelf, gated by `FeatureFlags.homeBannerEnabled` (off skips sampling + artwork loads)
- [x] Private `variableBlur` replaces the Metal progressive blur
- [x] Unified routes + zoom transitions (iOS/tvOS)
- [x] `TabsNavigationView` collapsed into one tab table + `RouteStack`
- [ ] Paginated Movies/Series/Search grids join the same store model
- [ ] Item-facts TTL cache (`MetadataCache`) for kino.pub details + enrichment
- [ ] Per-source TTL instead of one TTL passed ad hoc at call sites; stale read returns cache **and**
      kicks a background refresh
- [x] Shared image pipeline (dedupe, disk, prefetch) — Nuke, behind `Artwork`
      (`ArtworkPipeline.swift`), one decoded cache keyed by target size on all four platforms.
      **Palette is not part of it** and is still open
- [ ] Card → detail always seeds the hero from known artwork
- [ ] Launch: paint tabs and cached rails first; never block the shell on the whole session
      (a launch trace showed `history?perpage=20` alone at 96 KB, re-fetched every cold start)

### Detail page

- [ ] Artwork layer behind the scroll, hero content inside it, sections as data, playable rail first
      — the rules are in [AGENTS.md](AGENTS.md#the-detail-page); the history is in
      `docs/archive/plans/detail-page-choreography.md` (read with the "superseded" table at its top)
- [ ] Information / Languages / Technical columns become three `.focusSection()` groups, not
      link-by-link focus stops
- [ ] A centred "scroll to top" control at the true bottom of the page — guaranteed focus anchor and
      the Apple TV convention
- [ ] Section header appears **on focus**, not always (`SeasonsRailView.showsChrome` exists and is
      passed `true` unconditionally)
- [ ] One season → the tab strip must not be focusable at all; Down from the hero lands on an
      episode, and the tabs are reached only by Up *from* one
- [ ] Episode rail's leading card is the resume / next-unwatched episode, not chronological-first
- [ ] Replace the season tab strip with a real system pill/toggle component (`.borderless` is the
      interim, chosen so no hand-rolled focus code remains)
- [ ] KinoPub rating card: fold likes / dislikes / views into a fourth tile in the Ratings row, and
      decide what tapping it opens (asking for the user's own rating does not exist yet)
- [ ] tvOS section headers must not navigate — "see more" is a trailing card or button inside the
      row, never a separately-focusable header link
- [ ] Backdrop: one wide still that blurs as a material, not a second tiny poster raster
      cross-fading under it at rising opacity (their colours visibly disagree mid-fade)
- [ ] Investigate stranded/parallaxing posters in the person shelves — several sibling collections
      in one page region is the suspect shape. **Do not blind-fix**; it needs the transition watched

### Atoms and duplication

- [x] One artwork atom instead of ~15 `AsyncImage` call sites — `CachedRemoteImage` (configured) over
      `ArtworkImage` (the primitive). `AsyncImage` no longer appears in the repo
- [ ] De-duplicate the two initials-avatar implementations
- [ ] Collapse the 16 custom `ButtonStyle` types (separate pass)
- [ ] `MediaItemInfoColumns` → `Grid` / `GridRow`
- [ ] Replace remaining `.system(size:)` with `TypeScale` (measured 2026-08-05: 80 sites, 67 in the
      app target, 30 in `MediaItemDetailSections.swift` alone). Resolve the duplicate "big rating
      number" style against `TypeScale.ratingAggregate`. Audit, don't sweep
- [ ] Retire `Font.KinoPub` — superseded by `TypeScale`
- [ ] `@ScaledMetric` on square / hairline dimensions (measured: 1 use in the whole codebase)

### Accessibility

- [ ] `MediaCardView` gets an `accessibilityLabel`
- [ ] `RatingBadgeView` encodes tier only by colour — add a non-colour differentiator

### Observation model

Measured 2026-08-05: zero `@Observable`; 27 `ObservableObject`, 117 `@Published`, 39 `@StateObject`,
55 `@EnvironmentObject`. Migrate type by type — mixed is supported.

- [x] Pilot on leaf models (`ErrorHandler`, `WindowSettings`, `ProfileModel`)
- [ ] `HomeCatalog` — five `@Published` on one object re-evaluates the whole rows screen
- [ ] `AuthState`, `PlayerManager`, anything still on a Combine `$property` chain
- [ ] `NavigationState` **last** — `NavigationStack(path:)` needs a `Binding`, so it wants
      `@Bindable`, and it is the most connected object in the app

The pattern: drop every `@Published`; root owner `@StateObject` → `@State`; `.environmentObject` →
`.environment`; `@EnvironmentObject` → `@Environment(X.self)` (**which crashes if nothing was
injected on that branch** — re-check every injection point, not just the one you are editing); for a
binding off `@Environment`, shadow as `@Bindable var x = x` in the first line of `body`.
`@Observable` is a **precondition** for granular invalidation, not a win on its own.

---

## 2 — Access and app shell

**Goal:** reliable device-code / QR activation, and Settings as a real destination.

**Accepted:** full-screen activation modelled on the system AirPlay code; tokens in Keychain;
unauthorized state shows activation, not a broken shell.

**Activation screen — settled 2026-08-06, do not re-derive:**

- **No Copy button** — the whole code block is the copy target. Hover lightens every tile at once,
  the fill and never the glyphs. Click copies and confirms via `HudToast`.
- **Activate copies, then opens.** Sending someone to the site without the code on their clipboard
  means a second trip back.
- Activate is `.glassProminent`, focused on appear, `.defaultAction`, and **exactly as wide as the
  code block** (computed from tile metrics, not eyeballed).
- **Nothing moves while a code loads.** Five empty tiles at final size from frame one; characters
  arrive via `.blurReplace`. No spinner in the layout.
- Expiry is a draining ring **plus** the remaining time in figures — a ring alone reads as a spinner.
- The verification URL shows on every platform. tvOS has no copy target and no Activate button (no
  pasteboard, no browser); its footer keeps a fixed-height spacer so the layout still matches.

**Session lifetime:** a refresh rejection is **not** a sign-out. kino.pub rotates refresh tokens, so
a slightly stale token gets a 400 while the session is alive under the new one; treating that as
"session over" is what sends everyone back to activation. Only explicit
`logout(userInitiated: true)` clears shared state.

- [x] Device-code authorization + Keychain tokens + activation UI
- [x] Copy-code, expiry countdown, non-moving loader, Activate affordance
- [ ] **QR code on tvOS** — the remote has no pasteboard and no browser, so the phone camera is the
      real path off that screen. Must not move the tiles or the URL
- [ ] Activation error recovery (today it silently retries with a growing backoff and shows nothing)
- [ ] Settings as a first-class destination: General, Playback, Integrations, Diagnostics, About
      first; then Downloads (non-TV), Devices, Appearance, Sidebar, Notifications, Content/Metadata,
      Advanced. Native `Form` / `List` sections; hide platform-inappropriate groups
- [ ] Feature-gate incomplete panes rather than shipping fake toggles
- [ ] Auth changes must not wipe the Kinopoisk keychain service (separate — keep it that way)

**Validation:** cold launch → activation → authorized shell on tvOS and macOS · a code arriving and
being replaced on expiry move **nothing** · rebuilding or switching platform does not ask for a new
code · the screen is checked on screen, since it is only reachable signed out and therefore the
easiest screen in the app to ship broken.

---

## 3 — Library and History

**Goal:** one **Library** destination with a native sidebar of sections, each its own vertical
poster grid. History is a **section of that sidebar**, never a row merged into a Library scroll.

**Sections (business requirement — do not silently drop entries):**

| Section | Source | Notes |
| --- | --- | --- |
| **Watchlist** | `/v1/watching/serials?subscribed=1` | Default selection when Library opens; new-episode badge stays |
| **Movies** | `/v1/watching/movies` | Unfinished films. Endpoint implemented, currently **unused** — the gap vs the reference client |
| **History** | `/v1/history` | Its own section, its own grid |
| **Downloads** | local `DownloadsCatalog` | Order relative to History is not load-bearing |
| **Bookmark folders** | `/v1/bookmarks` | One row per folder **with its item count**, recently-updated first |
| **Create bookmark** | create-folder `POST` | Last row of the group |

Per platform: tvOS / iPadOS / macOS get sidebar + detail grid through system split APIs (never
hand-rolled Button-row sidebars). iPhone gets a Podcasts-shaped `List` of the same sections that
pushes to the grid.

- [x] `LibrarySection` model + per-section catalog on `ContentStore` (incl. `watchingMovies`)
- [x] Sidebar + detail grid shell on macOS; Library opens on Watchlist; folder counts match the
      reference client; no sidebar-toggle button in the window toolbar
- [ ] Same shell on iPadOS, and on tvOS with working focus (probe first)
- [ ] iPhone Podcasts-shaped list
- [ ] Create / delete bookmark folder from the sidebar (today creating one is only possible while
      bookmarking an item)
- [ ] Rename a folder **if** an endpoint exists — the public docs have none, but undocumented site
      endpoints do (lead: `kino.watch/favorites/update?id=`, unverified). Probe before declaring it
      impossible; do not ship a fake local-only rename
- [ ] Card actions: remove from history, remove from folder, unsubscribe
- [ ] Retire the superseded surfaces: `WatchlistView`, `RecentlyWatchedView`, `BookmarksView`,
      `PersonalLibraryCatalog`, and the matching `NavigationTabs` cases
- [ ] Paginate folder contents and history
- [ ] Cold launch paints cached section content before the network answers

**Superseded:** "one vertical scroll of rows for the whole Library" — it does not survive a user with
ten folders. Rows remain correct for **Home**, not for Library.

---

## 4 — KinoPub catalog completeness

**Goal:** surface what kino.pub already provides — collections, people, photos, similar, payload
metadata — before chasing external enrichment.

**Accepted:** detail pages show available native metadata without pretending we have personal
recommendations; similar items come from `GET /v1/items/similar`, never a "same genre"
approximation; people routes are first-class; decode and preserve quality / AC3 / age / artwork
fields even before every chip is designed.

### The playable graph

The data question the detail page kept trying to answer in the view layer:

```
Media
 ├── PlayableItem       episode · trailer · part · extra · the movie itself
 │     └── PlaybackVariant   24 fps · 48 fps · HDR · audio-track set
 └── Related media      other titles — a shelf, not a content type
```

- `PlayableItem` — id, title, duration, image, source, progress, kind. An episode and a trailer
  differ by `kind` and nothing else, so they render through one rail.
- `PlaybackVariant` — the *same* content encoded differently. **Built and verified 2026-08-16
  against the real `GET /v1/items/124447`** (fixture + tests in `KinoPubBackendTests`, sheet in
  [docs/providers/kinopub/video.md](docs/providers/kinopub/video.md)).
  The `s0e1` / `s0e2` in the original note was **exactly right**, in the API's own notation: each
  entry of `videos` carries `snumber: 0` and `number: 1…n`. There is no `seasons` key at all — the
  "fake episodes" live in `videos` on a `subtype: "multi"` item, with their own `id` and a human
  `title` ("24 fps", "48 fps"). **Multi-part films are this same mechanism**, not a second one.
  Subtitles and audio are **per entry** (55 vs 0 on that title), and `duration.total` is their
  **sum** while `average` is the film's runtime.
  `MediaItem.playbackVariants` + `VersionsRailView`; they never reach the episodes rail.
- The trailer is needed **before** the rail is, because the hero's Trailer button needs it.

- [x] **`GET /v1/items/{id}` mapped** from a captured response (124447): what distinguishes
      season/episode from part from fps variant, how a variant is requested and what the player is
      handed, what each variant carries (streams, qualities, codecs, audio, subtitles), and where
      the trailer lives. → [docs/providers/kinopub/video.md](docs/providers/kinopub/video.md), fixture +
      `MultiVersionItemTests`
- [ ] The rest of the kino.pub sheet — `items/similar` (cacheable? how slow?), collections,
      rewards, and the endpoints the item sheet does not cover. Same method: capture, then write
- [x] Similar items rail · cast/crew → person credits · detail shelves (more from director / with
      actor) · multi-country, ratings, synopsis, info/audio columns
- [x] A person's films are **one card per film**: the 3D encoding is a separate catalogue entry
      under the same credits (kinopoisk/imdb id shared — #9072 / #7319 are both The Lego Movie), so
      the person shelves and the person page collapse copies by `MediaItem.filmIdentity`, keeping
      the one that matches the page (3D title → 3D copy) and otherwise the better file. Shelves are
      picked by Kinopoisk rating and **shown newest first**. The library grid and search do not
      collapse — a "3D" type filter asks for exactly those entries
- [x] **Views, not a rating, break the ties** in those shelves and pick between two copies of a
      film. A score is only as good as the crowd behind it and we cannot count on a vote count
      being there — 5 Kinopoisk votes must not outrank a million on IMDb — while "how many people
      here opened it" is never missing and is already the "known for" signal
- [x] **Type/genre presentation is one profile**, `MediaPresentationProfile` — cast rail, hero
      credit lines, Credits card, author shelf. The rules themselves:
      [docs/product/media-presentation.md](docs/product/media-presentation.md)
- [x] **Every type recommends something**: similar → author → cast → collections → a genre floor
      that only fires when the rest came back empty. Concert asks its performers for concerts,
      stand-up asks its participants for anything and floats films/series. Rules:
      [docs/product/related-sections.md](docs/product/related-sections.md)
- [ ] Confirm `items/collections/{id}` answers on our host at all — captured from the PWA's
      `api2/v1.1` branch, wired best-effort, never seen answering. The log line is `item collections`
- [ ] Confirm `genre=5,23,101` really is OR (the vendor docs say nothing about it). The floor falls
      back to one genre when it answers empty; the log line is `genre floor`
- [ ] Fold `filter.genres` from `kpapp.link/config.json` into the app so the profile matches genre
      **ids** instead of RU/EN title strings — and so genre pickers stop needing a request
- [ ] Close the two open questions in that product doc: the poster / horizontal-card treatment per
      kind, and whether the actor shelf names the person while the author shelf names the role
- [ ] "Known for" ordering proper for person shelves — lead with the films the person is known for
      instead of the chronological fallback. Note the shelf is still *selected* server-side by
      `sort=-kinopoisk_rating`, so a title kino.pub has no Kinopoisk id for can be missing from
      page 1 before we ever rank it; `sort=-views` is the obvious thing to try there
- [ ] Trailers as items in the playable rail — not a movies-only section, not a hero takeover alone
- [ ] Collections browser + collection detail UI
- [ ] Vote (`GET /v1/items/vote`) + show own vote state
- [ ] Wire remaining filter chips (4K/HD/AC3/KP/IMDb min — client-side facets exist)
- [ ] Concert / special tracklists when present in the payload
- [ ] Explicit **recommendations gap**: document that personal recs are absent; do not fake them
- [ ] Comments endpoint — optional; port only if we commit to UI

### Catalog parity with the community fork

Their taxonomy and endpoints, our rows and focus. Full inventory:
`docs/archive/plans/community-parity-port.md`.

- [ ] `HomeCatalog.Shortcut` becomes a spec carrying `type` + `sort` + `period`, so the 9 home
      shelves, genre shelves and type shelves (concerts, 3D, documovies, docuseries, TV) are one
      mechanism. `RowKey` needs a case for filter-backed shelves. Keep the "drop empty shelves" rule
- [ ] A `CatalogSection` type — content type or genre preset (cartoons, cartoon series, anime,
      stand-up, 3D), each resolving to a `LibraryFilter`; `LibraryFilter` needs `rawType` for the
      anime preset. One generic "filtered catalog" screen that shelf headers and sections share.
      Do **not** grow the iPhone tab bar for them
- [ ] "New episodes" / "My series" screen with type sub-tabs; badge treatment reuses the card
      caption/progress structure — no new atom
- [ ] Person page: `LibraryFilter.person` gains an any-credit mode (both queries merged by item id,
      deduped, re-sorted); `MediaPerson` identity keys on the **name**, not `role:name`
- [ ] Filters: period menu, KP/IMDb minimum rating, HD / 4K / AC3 toggles, multi-select genres and
      countries, active-facet count badge. tvOS uses menus, not a sheet. Genre list reloads when the
      type changes. Undecided: `subtitles`, `language`, `translation`, `age`, `letter`, `finished`

---

## 5 — Platform completeness and appearance

**Goal:** deliberate light theme, Top Shelf, and platform integrations — **before** advanced
subtitles.

- [ ] Light theme design pass (semantic colours, materials, blur legibility, artwork contrast).
      Remove the forced dark scheme **only** when light actually works — not a partial toggle
- [ ] Top Shelf extension target + content provider. **Needs validation** on entitlement /
      extension packaging
- [ ] macOS Settings scene / menu wiring polished with stage 2
- [ ] iOS compact layout pass
- [x] Downloads feature-flagged (`FeatureFlags.downloadsEnabled`, compile-time)

Stages 1–4 should be usable first, so theme and Top Shelf wrap a coherent app rather than a
construction site.

---

## 6 — Discovery and enrichment

**Goal:** external metadata, artwork/logo/rating polish, editorial surfaces, and a **real**
recommendations source or an honest absence.

Today's plumbing is an early slice, not the target shape — the aggregator (crawled catalogue behind
one API, keyed by our own title id, per-field provenance, people as entities) is the `metadata-service`
skill, and its known defects are listed there. Read those before assuming any current behavior is a
decision.

**Accepted:** TMDB through our worker proxy; Kinopoisk Unofficial per-user key + keyless proxy
fallback; enrichment sections hide when empty; the detail hero holds the lettered title until
enrichment settles, assuming a logo will load, and paints text only when there is no URL or the
image fails.

- [x] TMDB cast photos / characters / logos / air dates · Kinopoisk awards / facts / stills / RU names
- [x] Ratings **and** Reviews as one `BlockCard` rail + full-list page, iOS/macOS, running beside
      the shipped tile row until one wins. Sheet:
      [docs/providers/kinopoisk-proxy.md](docs/providers/kinopoisk-proxy.md). Reviews are still page 1 of N
- [x] Aggregate weighs IMDb + Kinopoisk + TMDB + kino.pub thumbs, by turnout
- [ ] Settings: tick which rating sources count and weigh them (`RatingWeights` is in place and
      defaults to all-on, equal — only the pane and its persistence are missing)
- [ ] The rest of the detail page onto `BlockCard` — facts, photos, information columns (not tvOS)
- [ ] Surface TMDB tagline / box office / company logos; Kinopoisk premiere dates
- [ ] Deeper person-bio enrichment (deferred id strategy)
- [ ] Decide the recommendations approach — Trakt scrobble, local taste, editorial-only, or none
- [ ] Editorial Home rows, if a legitimate source is chosen
- [ ] Server-side "donate" of pulled metadata — postponed until there is a backend

---

## 7 — Playback conveniences

**Goal:** playback memory, skip intro/recap/credits, and Up Next — **without** rewriting the native
player.

**Accepted:** the native controller stays, and it has to be **populated**, not sat beside. macOS
plays in **its own window** — sidebar and player on screen together is a bug, not a layout. Skip and
Up Next use the system affordances before any custom overlay is considered.

The rich Info / Related / Up Next surface is a **tvOS** deliverable: on iOS the honest native scope
is `externalMetadata` + speed + PiP, and on macOS `externalMetadata` does not exist at all. The
per-platform API matrix is in the `player-avkit` skill — do not plan iOS or macOS work around the
tvOS-only properties.

- [x] Custom centre panel deleted; a failure shows a system alert and we stay in the player
- [x] `externalMetadata` on iOS as well as tvOS
- [x] Every play entry point goes through `PlayerLink`; `NavigationState.push` redirects player
      routes into the macOS playback window, with a `RouteDestination` guard behind it
- [x] macOS `AVPlayerView` bridge (speeds, PiP, fullscreen toggle, sharing)
- [x] Per-show subtitle track memory; dual subtitles (tvOS, parked defaults)
- [x] Ambient hero preview stops when a real playback session starts elsewhere. **General rule:** any
      preview player outside `PlaybackSession` must be wired to that signal — it does not get it free
- [ ] tvOS Info tabs (`customInfoViewControllers`), `infoViewActions` (Watchlist, From beginning)
- [ ] Up Next via `AVContentProposal`, driven by the existing next-episode logic
- [ ] Chapters via `navigationMarkerGroups`, once any marker source exists
- [ ] Subtitle overlay inside the controller (`customOverlayViewController` + `unobscuredContentGuide`,
      styling from `MediaAccessibility`) instead of a SwiftUI sibling in a `ZStack`
- [ ] Re-check `allowedSubtitleOptionLanguages = []` — hiding the system picker is only justified
      while our menu is a strict superset. `AVCustomMediaSelectionScheme` (26+) may let sidecar SRT
      live in the system menu instead
- [ ] PiP that survives backgrounding on iOS (needs an `AVAudioSession` `.playback` category and
      `UIBackgroundModes: audio`; `allowsPictureInPicturePlayback` alone stops at backgrounding)
- [ ] Verify AirPlay / Now Playing / Control Center titles and artwork on every platform
- [ ] Per-show audio track memory; fix subtitles-follow-episode (`MediaItem.subtitles` reads the
      first video only)
- [ ] Skip data — subtitle-gap heuristic first, into `contextualActions`; then TheIntroDB (IMDb/TMDB
      keys) cached per episode; AniSkip once a MAL/AniList match exists
- [ ] End-of-playback behavior + its Settings decision; resume-prompt default documented
- [ ] Resume race (`onAppear` → `fetchWatchMark` → seek) and resume reading the wrong episode
- [ ] SRT fetch needs encoding detection (Russian subs are routinely windows-1251); cue lookup
      should be a binary search + cursor, not a linear scan over ~2000 cues several times a second
- [ ] Player lifetime: drop the second periodic observer, stop republishing `currentPlaybackTime`
      four times a second, clean up `HLSAudioLabeler`'s temp `.m3u8` files
- [ ] Compare `AVPlayerView.controlsStyle` variants side by side against TV.app / Music.app before
      concluding anything is or is not reachable public API — screenshots, not memory

---

## 8 — Advanced subtitles

**Goal:** subtitle intelligence, translation and language learning — **only after** stages 1–7 make
a usable daily client. Large, version-sensitive (some live transcription is tvOS 27+), and easy to
derail on.

- [ ] Un-park tap-a-word with real remote focus validation — the word chips in
      `SubtitleTranslatePanel` have no focusable treatment and are unusable on a remote as written
- [ ] Default English non-CC policy stays configurable
- [ ] OpenSubtitles / external fallback when kino.pub has no tracks
- [ ] tvOS 27+ live caption experiments behind availability checks
- [ ] Learning-oriented UI only with an explicit product brief

Depends on a stable player session, per-show track memory, and catalog IDs from earlier stages.
