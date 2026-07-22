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
- **Dual subtitles**: any two of the item's tracks at once, stacked at the bottom of the frame, picked
  from a captions button in the player and remembered for the next episode
- On-pause word panel translating EN→RU on device (iOS 18 / macOS 15; not available on tvOS)

## Known issues / half-finished

These are real, verified, and up for grabs:

- **The pause panel's focus behaviour is unverified on a real remote.** The word chips now use a
  focus-reactive button style, but nobody has driven it with a Siri Remote yet.
- **Subtitles don't follow the episode.** `MediaItem.subtitles` returns `videos?.first?.subtitles`, so a
  series always uses the first video's tracks. See `Packages/KinoPubBackend/.../Models/MediaItem.swift`.
- **Player chrome conflicts on tvOS.** `PlayerView` layers a custom back button, a captions button and
  subtitle views over `VideoPlayer`; on tvOS the native transport UI fights them. The chrome is now
  disabled while it is hidden, so it no longer takes focus during playback, but the two layers still
  compete when it is showing.
- **The subtitle picker has not been driven with a Siri Remote.** `SubtitleTrackPickerView` is a sheet
  of focusable rows over the player; it builds and the rows are standard `Button`s, but nobody has
  opened it on a real Apple TV against a real stream.
- **Home and Saved rows show only the first page** of each shortcut or folder, and refetch every
  time the tab appears. `/v1/bookmarks/{id}` is not paginated in `BookmarkItemsRequest`, so a folder
  row stops at what one request returns — the folder's own screen has the same limit.
- **Year filtering is by decade**, not an arbitrary from/to — a two-ended numeric picker is painful
  with a remote. The API accepts any range if that changes.
- **Continue watching shows the last-played episode, not the next one.** Working out "next" needs a
  per-item `/v1/watching?id=` call; the row shows where playback stopped instead.
- **A title played longer ago than the last 50 history entries** falls back to its poster, cropped to
  the landscape frame, with no episode label.
- **Bookmarking needs an existing folder.** There is no create-folder flow yet, so the button is
  disabled on an account with none.
- **The hero trailer only appears when the API returns `trailer.url`.** Some items carry a `trailer`
  object with no link; the button is hidden and the artwork stays.
- **Some trailer files carry black borders baked into the picture** («Обсессия» is one), so the hero
  shows them. The player layer fills the frame — the padding is in the source, and cropping it away
  would cut into trailers that don't have it.

## Target UX

What "done" looks like, so nobody has to guess:

- **Saved is rows too** — one per bookmark folder, the one added to most recently on top, the count
  beside the title in secondary type. The title leads to the folder's own full screen; the artwork
  is on the tab itself, so nothing has to be opened before you can see what's in it.
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
- Detail page: full-bleed hero with a Metal variable blur, the trailer playing muted behind the
  artwork, native action buttons, season tabs over a rail of episode stills
- Tabs: Search · Home · Movies · Series · Saved · Settings, icon-only where it should be
- Combined score badges on posters, separate IMDb/Kinopoisk marks on detail pages
- White accent throughout; the site's green is gone

### Phase A — Plan-minimum: parity with what I already use

Nothing exotic. A working, good-looking client that does what microiptv does.

- [x] **Library browsing in the Search tab**, matching microiptv's Library:
  - all seven sorts, recently added by default. `kinopoisk_rating` and `imdb_rating` are not in the
    docs but the service accepts and orders by them — verified against live responses
  - dropdown filters: type, genre, country, release decade
  - pickers fed by `/v1/genres` and `/v1/countries`
- [x] **Wire the Watched and Bookmark buttons** — Watched hits `/v1/watching/toggle`; Bookmark opens
  the account's folders and toggles membership via `/v1/bookmarks/toggle-item`
- [ ] Paginate home rows; cache them so returning to the tab doesn't refetch everything
- [ ] Fix the player issues listed under Known issues (subtitle track per episode, tvOS transport
      conflicts) — CC/forced detection is done: `SubtitleTracks` matches markers as whole words and
      treats forced as its own flag, never a default

### Phase B — All of kino.pub's data

microiptv leaves a lot on the table. We shouldn't.

- [x] **The trailer plays behind the hero artwork** — muted, a beat after the page settles, filling
      the frame with no transport chrome, dropping back to the artwork when it ends
- [ ] Trailers on the detail page as a proper section, not only the hero takeover
- [ ] Awards
- [ ] Collections (`GET /v1/collections`, `/v1/collections/view?id=`)
- [x] **Every production country**, not just the first — microiptv shows one
- [x] Ratings section: IMDb and Kinopoisk with vote counts, then kino.pub's own thumbs up/down
      tally shown as the tally it is rather than a fake score
- [x] Cast and crew as round portraits
- [x] Information · Translation · Audio columns, stacking when the display is narrow
- [x] Synopsis as a focusable panel that opens the full text, rather than expanding in place
- [ ] Cast photos and character names — kino.pub sends neither, so portraits are initials.
      See Phase C½: Kinopoisk Unofficial has both
- [ ] Sweep the rest of the payload (quality, AC3, age rating)
- [ ] Similar items (`GET /v1/items/similar`)

### Phase C — Remember playback choices

The subtitle *default* already exists (Profile → Playback: on/off and prefer-non-CC, English first
rather than the system language). What's missing is memory of what the user picked mid-watch.

- [x] **Remember the last subtitle track chosen for a series** and pre-select it for the next episode,
      falling back to the default preference — microiptv forgets every episode, which is the thing
      worth beating. Sidecar URLs differ per episode, so the choice is stored as language + CC-ness +
      position within that language (`SubtitleTrackReference`) and re-resolved against each episode's
      tracks; "off" is remembered as a choice too.
- [ ] Same for the audio track
- [x] **Dual subtitles** — an option, off by default, showing any two of the item's tracks at once.
      Which two is the user's call: a captions button in the player lists every track the item offers
      and takes a first and a second pick, in any language. They render as one block at the bottom of
      the frame, the second line under the first and slightly smaller, rather than split top and
      bottom — eyes that have to travel across the screen miss both. Each track keeps its own timings.
      Profile → Playback only seeds the default second language for items nothing was picked on yet.

### Phase C½ — Kinopoisk Unofficial API

kino.pub itself pulls from **Kinopoisk API Unofficial** (`kinopoiskapiunofficial.tech`), which is
where richer Russian-language data lives: staff with photos and character names, awards, premiere
dates, similar titles, box office. Worth wiring around the same time as Phase C, since it fills gaps
the kino.pub payload simply doesn't have.

- Some endpoints answer without a key; the fuller ones need a free key. Confirm which we need before
  deciding whether to ship a key at all.
- Matching is by IMDb or Kinopoisk id — `MediaItem.imdb` and `MediaItem.kinopoisk` both exist.

- [ ] Confirm what works keyless versus keyed
- [ ] Cast photos and character names — the one gap that makes our round portraits initials
- [ ] Awards, premiere dates, similar titles

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

### Phase E — Skip intros, recaps and credits

Two tiers, and the cheap one is worth shipping first:

- **Minimum, from subtitles.** A gap in the subtitle track at the head of an episode, or a repeated
  cue block across episodes of a season, approximates the intro well enough to offer a Skip button.
  Needs no external service and the cue parser already exists.
- **Proper, from a segment database.** Community sources keyed by ids we can reach:
  - **TheIntroDB** (`introdb.app`) — open REST API of intro/recap/outro timecodes, keyed by TMDb,
    IMDb and TVDb ids. Used by Jellyfin's Media Segments and Stremio. `MediaItem.imdb` gives the key.
  - **AniSkip** (`api.aniskip.com/v2/skip-times/{mal_id}/{episode}`) — the accurate one for anime,
    with typed segments (`op`, `ed`, `recap`, `mixed_op`). Keyed by MAL/AniList id, so it needs a
    title match rather than an id we already hold.
  - **Anime-Skip** — similar, with finer segments (intro, canon, filler, preview).
- **Fallback, computed locally.** Audio fingerprinting is what Plex and Jellyfin's Intro Skipper
  actually do: hash the audio of several episodes in a season (Chromaprint/`fpcalc` + FFmpeg) and find
  the repeated 30–90s run. Accurate and source-independent, but it needs the files — plausible for
  downloads, not for streaming, so it is the last resort rather than the plan.

- [ ] Subtitle-gap heuristic + a Skip control in the player
- [ ] TheIntroDB lookup by IMDb id, cached per episode
- [ ] AniSkip for anime, once there is a MAL/AniList match
- [ ] Decide whether fingerprinting is worth it for downloaded files only

### Phase F — Episode schedule

- [ ] Show air dates on episode cards, including episodes not out yet ("Ep 6 · 14 Aug")
- [ ] Mark upcoming episodes as unplayable rather than hiding them
- [ ] Source: kino.pub's own data if it carries dates, otherwise TVDb/TMDb by IMDb id

### Later
- [ ] TV channels tab (`GET /v1/tv/index`)
- [ ] Viewing history screen
- [ ] Top Shelf extension
- [ ] tvOS card parallax — needs TVUIKit via `UIViewRepresentable`; SwiftUI has no equivalent


## API notes

Reference: **[kinoapi.com](https://kinoapi.com)** — the kino.pub API v1.3 documentation. It is the
right map, but it dates from around 2020 and is not always what the service actually returns, so
anything load-bearing gets checked against a live response first. Cases where reality differed:

- `/v1/history` entries carry a `media` object (episode still, season/episode numbers, runtime) and
  an `item` with the **wide** poster. None of that is in the docs, and it is what the landscape
  Continue Watching cards are built from.
- `rating` is the **net** vote count and goes negative; `rating_percentage` is the positive share.
  Reading `rating` as a score would have printed "36 / 10".
- `/v1/watching/*` omits `posters.wide`, but the same id is served under a `/wide/` path.
- A bookmark folder's `updated` tracks its **contents**, not views — reading the folder repeatedly
  leaves it alone, and `/v1/bookmarks/{id}` echoes the same value under `folder`. The items it
  returns carry no per-membership date, so `updated` is the only way to order folders by when
  something was last added to them (`Bookmark.recentlyUpdatedFirst`).

Where a payload shape matters, a decoding test pins the real JSON (see `HistoryEntryTests`) so an
upstream change fails loudly instead of silently emptying a row.

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
