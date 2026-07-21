# kino.pub Apple TV client

A native SwiftUI client for the [kino.pub](https://kino.pub) service, **built tvOS-first**.

This is a fork of [leoru/kinopub-apple-client](https://github.com/leoru/kinopub-apple-client), which targets
iOS/iPadOS/macOS. The goal of this fork is different: make a proper **Apple TV** app.

Two reference points guide the work:

- **Look & feel** — the stock Apple TV app. Horizontal rows of artwork, generous focus effects, native
  controls, nothing that looks like a website ported to a 10-foot screen.
- **Feature set** — [microiptv](https://apps.apple.com/ae/app/microiptv/id6469873633), the app people
  actually use for kino.pub on Apple TV today. Its tab layout and library filters are the functional bar.

Plus one thing neither of them does: **language learning while watching** — English subtitles on by default
(non-CC), pause, and get a translation for any word you didn't catch.

## Status

| Platform | Priority | State |
| --- | --- | --- |
| tvOS 17+ | **Primary** | Builds and runs. Home is rebuilt; detail page and player still to go. |
| iOS / iPadOS 16+ | Secondary | Works (inherited from upstream). Kept building, not designed for. |
| macOS 15+ | Secondary | Works (sidebar layout). Kept building, not designed for. |

Non-goals for now: analytics/crash reporting (Firebase has been removed), Downloads on tvOS, and any
custom theming that fights the platform HIG.

## Requirements

- Xcode 16
- Swift 5.9
- Deployment targets: tvOS 17.0, iOS 16.0, macOS 15.0

`KinoPubUI` contains a Metal shader (`Shaders/VariableBlur.metal`). Xcode 26+ ships the Metal
toolchain as a separate component — if the build fails with "missing Metal Toolchain", run:

```
xcodebuild -downloadComponent MetalToolchain
```

There is a **single multiplatform target** (`KinoPubAppleClient`, product name `KinoPub`) covering all
platforms. Platform differences live in `#if os(tvOS)` / `#if os(iOS)` / `#if os(macOS)` blocks — please
do not add a second target.

```
open KinoPubAppleClient.xcodeproj
# then pick the "Apple TV" destination
```

## What works today

- Device-code authorization against the kino.pub API, tokens in the Keychain
- Catalog browsing: `hot` / `fresh` / `popular` per content type, paginated
- Search, bookmarks (folders + items), item details, seasons and episodes
- Playback with resume ("continue watching" prompt) and watch-mark reporting
- Downloads and offline playback (iOS/iPadOS/macOS only)
- **English subtitles by default**, preferring non-CC/SDH sidecar tracks, parsed into synced cues and
  rendered as an overlay (`Views/Player/Subtitle*.swift`); toggles live in Profile → Playback
- On-pause word panel translating EN→RU on device (iOS 18 / macOS 15; not available on tvOS)

## Known issues / half-finished

These are real, verified, and up for grabs:

- **The pause panel's focus behaviour is unverified on a real remote.** The word chips now use a
  focus-reactive button style, but nobody has driven it with a Siri Remote yet.
- **Subtitles don't follow the episode.** `MediaItem.subtitles` returns `videos?.first?.subtitles`, so a
  series always uses the first video's tracks. See `Packages/KinoPubBackend/.../Models/MediaItem.swift`.
- **Player chrome conflicts on tvOS.** `PlayerView` layers a custom back button and subtitle views over
  `VideoPlayer`; on tvOS the native transport UI fights them.
- **CC detection is sloppy.** `SubtitleSelector.looksLikeCC` builds a regex by interpolating the marker
  into `#"\b\#(marker)\b"#`, and counts `forced` as a CC marker — forced tracks carry no dialogue and make
  a bad default.
- **Home rows show only the first page** of each shortcut and refetch every time the tab appears.
- **Continue watching shows the last-played episode, not the next one.** Working out "next" needs a
  per-item `/v1/watching?id=` call; the row shows where playback stopped instead.
- **A title played longer ago than the last 50 history entries** falls back to its poster, cropped to
  the landscape frame, with no episode label.
- **The detail page's Watched and Bookmark buttons are inert.** They are wired to empty closures.
- **The hero trailer only appears when the API returns `trailer.url`.** Some items carry a `trailer`
  object with no link; the button is hidden and the artwork stays.

## Target UX

What "done" looks like, so nobody has to guess:

- **Home** is rows, not a grid. First row is **Continue watching**, then category/collection rows.
  **No hero banner** — there are no personalized recommendations to justify one; it would just be a
  big advert.
- **Continue watching is a landscape row** — episode stills for series, wide artwork for films, with
  a play glyph, resume bar and "S2, E5 · 42 min" over the image. It reads as a different kind of row
  from the poster shelves below it, the way the Apple TV app treats it.
- **Continue watching is ordered by intent, not by update date**: things watched in the last week that
  were never added to the watchlist come first (easiest to forget), then the watchlist itself, then
  everything else unfinished. Most recently played first within each group.
- **Poster cards carry one combined score** in the top-left (detail pages show the two sources
  separately instead, where there is room): the average of IMDb and Kinopoisk when
  both rated it, otherwise whichever did, hidden when neither. Colour by tier — gold with laurel wings
  at 8.0+, green from 7.0, grey from 6.0, red below. The tier follows the *displayed* value, so a card
  reading "8.0" always gets the gold treatment.
- **Detail page** leads with artwork that gives way to the **trailer**, blurred progressively toward
  the overlaid title, metadata and plot; then season tabs over a rail of episode stills.
  Native tvOS buttons — no tiny iOS-sized controls.
- **White is the accent colour**, as on Apple TV. The site's green is gone; the only coloured chrome
  left is semantic (rating tiers, destructive actions).
- **Tabs** across the top: 🔍 · Home · Movies · Series · Saved · ⚙️. On tvOS the labelled tabs are
  text-only (tvOS tab bars are text) and Search and Settings are icons alone; other platforms show
  icon + label. Search owns the query field along with the sort and filter controls, everywhere.
- Downloads tab exists only on non-TV platforms.
- Apple HIG throughout; if a stock Apple TV app doesn't do it, we probably shouldn't either.

## Roadmap

The goal in one line: **a client good enough to replace microiptv for daily use.** Everything below
that line is polish, and everything above it is unfinished business.

### Done so far
- tvOS build hygiene, CI across tvOS/iOS/macOS, all four package test suites green
- Row-based home led by Continue Watching, ordered by intent and rendered as landscape cards with
  episode stills, resume bars and "S1, E7 · 51 min"
- Detail page: full-bleed hero with a Metal variable blur, trailer takeover, native action buttons,
  season tabs over a rail of episode stills
- Tabs: Search · Home · Movies · Series · Saved · Settings, icon-only where it should be
- Combined score badges on posters, separate IMDb/Kinopoisk marks on detail pages
- White accent throughout; the site's green is gone

### Phase A — Plan-minimum: parity with what I already use

Nothing exotic. A working, good-looking client that does what microiptv does.

- [ ] **Library browsing in the Search tab**, matching microiptv's Library:
  - sorts: recently added *(default)*, recently updated, views, title, year, Kinopoisk rating,
    IMDb rating — `GET /v1/items` takes `sort` with a `-` prefix for descending
  - filters as dropdowns: type, genre, country, release-year range
  - pickers fed by `/v1/types`, `/v1/genres`, `/v1/countries`
- [ ] **Wire the Watched and Bookmark buttons** — they render but do nothing
  (`/v1/watching/toggle`, `/v1/bookmarks`)
- [ ] Paginate home rows; cache them so returning to the tab doesn't refetch everything
- [ ] Fix the player issues listed under Known issues (subtitle track per episode, tvOS transport
      conflicts, CC/forced detection)

### Phase B — All of kino.pub's data

microiptv leaves a lot on the table. We shouldn't.

- [ ] Trailers on the detail page as a proper section, not only the hero takeover
- [ ] Awards
- [ ] Collections (`GET /v1/collections`, `/v1/collections/view?id=`)
- [ ] **Every production country**, not just the first — microiptv shows one
- [ ] Sweep the item payload for anything else worth surfacing (voices, quality, AC3, tracklist)
- [ ] Similar items (`GET /v1/items/similar`)

### Phase C — Remember playback choices

The subtitle *default* already exists (Profile → Playback: on/off and prefer-non-CC, English first
rather than the system language). What's missing is memory of what the user picked mid-watch.

- [ ] Remember the last subtitle track chosen for a series and pre-select it for the next episode,
      falling back to the default preference — microiptv forgets every episode, which is the thing
      worth beating
- [ ] Same for the audio track
- [ ] **Dual subtitles** — Russian on top, English below, for watching in English with a safety net.
      Nothing else does this; the cue overlay already exists to build on.

### Phase D — Exploratory: IMDb-sourced top lists

**Tops and curated lists only** — kino.pub's own are tired. Personal recommendations are explicitly
not wanted for now (the owner isn't logging IMDb ratings), and "similar" doesn't need IMDb anyway.

The idea: reproduce IMDb's editorial lists as rows, composed from kino.pub's catalog —
*Top 10 on IMDb this week*, *In theaters*, *Top box office (US)*, *Current & upcoming TV shows* —
either mapping each to what kino.pub carries, or reverse-matching by IMDb id (`MediaItem.imdb` has it).

Sourcing, and the two routes are not equivalent:
- **Official non-commercial datasets** (`datasets.imdbws.com`, mirrored on S3) — daily TSVs of
  `title.basics`, `title.ratings`, `title.akas`. Legitimate for personal use and enough for
  rating/vote-count tops, but they carry **no editorial lists** — "this week", "in theaters" and
  "box office" are not in the dumps.
- **Scraping / unofficial wrappers** reach the editorial lists but break without warning and sit
  outside IMDb's terms.

- [ ] Decide the source per list, given the above
- [ ] Map IMDb ids to kino.pub items, skipping what the service doesn't carry
- [ ] Render the surviving lists as Home rows

### Later
- [ ] TV channels tab (`GET /v1/tv/index`)
- [ ] Viewing history screen
- [ ] Top Shelf extension
- [ ] tvOS card parallax — needs TVUIKit via `UIViewRepresentable`; SwiftUI has no equivalent


## API notes

The service exposes far more than the app currently uses ([API v1.3 docs](https://kinoapi.com)).

**Already wired** (`Packages/KinoPubBackend/Sources/KinoPubBackend/Requests/`):
`/v1/items/{hot,fresh,popular}`, `/v1/items/search`, `/v1/items/{id}`, `/v1/user`, `/v1/bookmarks`,
`/v1/bookmarks/{id}`, `/v1/watching`, `/v1/watching/movies`, `/v1/watching/serials`,
`/v1/watching/marktime`, `/v1/watching/toggle`, `/v1/history`, `/v1/genres`, `/v1/countries`,
device-code auth.

**Available, not yet wired:**

| Endpoint | Use |
| --- | --- |
| `GET /v1/items` | Library with `type,genre,country,year,finished,actor,director,letter,quality,sort` (`sort`: id, year, title, created, updated, rating, views, watchers; `-` prefix = descending) |
| `GET /v1/items/similar?id=` | Similar titles on the detail page |
| `GET /v1/tv/index` | TV channels tab |
| `GET /v1/collections`, `/v1/collections/view?id=` | Curated rows |
| `GET /v1/types` | Content-type reference for filters |

## App structure

Swift Package Manager, one app target plus four local packages:

- `KinoPubAppleClient` — the app target; all shared UI and app logic
- `KinoPubUI` — reusable SwiftUI components (cards, buttons, poster styles)
- `KinoPubKit` — shared business logic (downloading, file storage)
- `KinoPubBackend` — networking layer and API models
- `KinoPubLogging` — small OSLog extensions

Inside the app target:

- `App` — application lifecycle
- `Views` — SwiftUI views grouped by feature (`Main`, `MediaItem`, `Player`, `Bookmarks`, `Downloads`, `Profile`, `Root`, `macOS`)
- `Services` — API-backed services (content, user, auth, downloads, keychain)
- `States` — navigation, auth and error state objects
- `Context` — `AppContext` dependency container
- `Custom` — assorted helpers
- `Resources` — assets and localizations

## Third-party libraries

- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) — token storage
- [SkeletonUI](https://github.com/CSolanaM/SkeletonUI) — loading placeholders
- [PopupView](https://github.com/exyte/PopupView) — error toasts
- [Reachability](https://github.com/ashleymills/Reachability.swift) — connectivity

Firebase was removed; analytics and crash reporting are out of scope.

## Contributing

Agents and humans: read [AGENTS.md](AGENTS.md) before changing code.

- Open a [feature request](https://github.com/HipsterCat/kinopub-apple-client/issues/new?template=feature_request.md)
  or a [bug report](https://github.com/HipsterCat/kinopub-apple-client/issues/new?template=bug_report.md)
- Pull requests welcome — please say which roadmap phase your change belongs to

## Credits

Built on top of [leoru/kinopub-apple-client](https://github.com/leoru/kinopub-apple-client) by Kirill Kunst
and contributors. Fixes that aren't tvOS-specific are worth sending upstream too.
