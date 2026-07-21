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
| tvOS 17+ | **Primary** | Builds and runs; UI is still the iOS layout. Active work. |
| iOS / iPadOS 16+ | Secondary | Works (inherited from upstream). Kept building, not designed for. |
| macOS 15+ | Secondary | Works (sidebar layout). Kept building, not designed for. |

Non-goals for now: analytics/crash reporting (Firebase has been removed), Downloads on tvOS, and any
custom theming that fights the platform HIG.

## Requirements

- Xcode 16
- Swift 5.9
- Deployment targets: tvOS 17.0, iOS 16.0, macOS 15.0

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
- On-pause word panel that is *meant* to translate EN→RU on device — see Known issues

## Known issues / half-finished

These are real, verified, and up for grabs:

- **Word translation never fires.** `SubtitleTranslatePanel.translate(word:)` sets a
  `TranslationSession.Configuration` on the panel's own `@State`, but the only `.translationTask` sits
  inside the private `TranslatedBody` wrapper with a *separate*, never-assigned configuration — so
  `performTranslation(session:)` has no caller. `TranslationTransformModifier` is dead code.
  See `KinoPubAppleClient/Views/Player/SubtitleTranslatePanel.swift`.
- **Word chips aren't focusable on tvOS.** They are `.buttonStyle(.plain)` inside a `LazyVGrid`, so the
  Siri Remote can't reach them.
- **Subtitles don't follow the episode.** `MediaItem.subtitles` returns `videos?.first?.subtitles`, so a
  series always uses the first video's tracks. See `Packages/KinoPubBackend/.../Models/MediaItem.swift`.
- **Player chrome conflicts on tvOS.** `PlayerView` layers a custom back button and subtitle views over
  `VideoPlayer`; on tvOS the native transport UI fights them.
- **CC detection is sloppy.** `SubtitleSelector.looksLikeCC` builds a regex by interpolating the marker
  into `#"\b\#(marker)\b"#`, and counts `forced` as a CC marker — forced tracks carry no dialogue and make
  a bad default.
- **Home rows show only the first page** of each shortcut and refetch every time the tab appears.

## Target UX

What "done" looks like, so nobody has to guess:

- **Home** is rows, not a grid. First row is **Continue watching**, then category/collection rows with
  artwork and IMDb/Kinopoisk ratings on the cards. **No hero banner** — there are no personalized
  recommendations to justify one; it would just be a big advert.
- **Detail page** leads with the **trailer** playing at the top, then title/metadata/cast, then seasons.
  Native tvOS buttons — no green site-styled buttons, no tiny iOS-sized controls.
- **Tabs** across the top, text-only on tvOS (no SF Symbols — tvOS tab bars are text):
  Search · Movies · Series · Mine · Library · TV · Settings. Search owns the query field along with
  the sort and filter controls, on every platform.
  "Mine" = unfinished movies/serials + bookmark folders. "Library" = the full catalog with filters.
- Downloads tab exists only on non-TV platforms.
- Apple HIG throughout; if a stock Apple TV app doesn't do it, we probably shouldn't either.

## Roadmap

### Phase 0 — tvOS hygiene ✅
- [x] Verify and keep green a `platform=tvOS Simulator` build in CI (`.github/workflows/ci.yml`)
- [x] Remove the stale `GoogleService-Info.plist` reference from `project.pbxproj`
- [x] Text-only tab labels on tvOS; Downloads tab hidden there
- [x] Audit every custom `Button` / `NavigationLink` for focus behaviour on tvOS —
      `KinoPubButtonStyle` and the subtitle word chips now react to focus
- [x] Repair the `KinoPubKit` / `KinoPubUI` test targets and add them back to CI
- [x] Hide the item-page download button on tvOS

### Phase 1 — Home rebuild
- [x] Move search, sort and filters out of Main into their own Search tab (all platforms)
- [x] Row-based home model (sections of horizontally scrolling cards) replacing the flat `LazyVGrid`
- [x] Wire `GET /v1/watching/movies` + `GET /v1/watching/serials` → "Continue watching" row
- [x] Rows per shortcut and content type (Hot / Fresh / Popular, Movies / Series)
- [x] tvOS card component with focus scaling, ratings, watch progress and new-episode badges
- [ ] Paginate rows as they scroll (each row currently shows the first page only)
- [ ] Cache the home rows so returning to the tab doesn't refetch everything

### Phase 2 — Detail page
- [ ] Trailer at the top, autoplaying, muted-until-focused
- [ ] Native tvOS action buttons (Watch / Trailer / Bookmark / Watched)
- [ ] Seasons & episodes redesigned as rows with stills and progress
- [ ] Similar items row via `GET /v1/items/similar`

### Phase 3 — Navigation & Library
- [ ] Tab set: Search · Movies · Series · Mine · Library · TV · Settings
- [ ] Hide Downloads on tvOS
- [ ] "Mine" tab: unfinished serials/movies + bookmark folders
- [ ] Library filters wired to `GET /v1/items` (type, genre, country, year, quality, sort)
- [ ] Filter pickers fed by `/v1/types`, `/v1/genres`, `/v1/countries`

### Phase 4 — Player & subtitles
- [ ] Fix the Apple Translation wiring so the pause panel actually translates
- [ ] Make the word panel focus-navigable on tvOS
- [ ] Per-episode subtitle tracks
- [ ] Subtitle appearance settings (size, background); revisit CC/forced detection
- [ ] Reconcile custom overlays with the native tvOS transport bar

### Phase 5 — Later
- [ ] Collections rows (`/v1/collections`)
- [ ] TV channels tab (`/v1/tv/index`)
- [ ] Viewing history (`/v1/history`)
- [ ] Top Shelf extension

## API notes

The service exposes far more than the app currently uses ([API v1.3 docs](https://kinoapi.com)).

**Already wired** (`Packages/KinoPubBackend/Sources/KinoPubBackend/Requests/`):
`/v1/items/{hot,fresh,popular}`, `/v1/items/search`, `/v1/items/{id}`, `/v1/user`, `/v1/bookmarks`,
`/v1/bookmarks/{id}`, `/v1/watching`, `/v1/watching/marktime`, `/v1/watching/toggle`, `/v1/genres`,
`/v1/countries`, device-code auth.

**Available, not yet wired:**

| Endpoint | Use |
| --- | --- |
| `GET /v1/watching/movies` | Unfinished movies → Continue watching |
| `GET /v1/watching/serials?subscribed=` | Serials with new episodes → Continue watching / Mine |
| `GET /v1/items` | Library with `type,genre,country,year,finished,actor,director,letter,quality,sort` (`sort`: id, year, title, created, updated, rating, views, watchers; `-` prefix = descending) |
| `GET /v1/items/similar?id=` | Similar titles on the detail page |
| `GET /v1/collections`, `/v1/collections/view?id=` | Curated rows |
| `GET /v1/tv/index` | TV channels tab |
| `GET /v1/history` | Viewing history |
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
