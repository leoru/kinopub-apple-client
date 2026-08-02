# kino.pub Apple TV client

A native SwiftUI client for the [kino.pub](https://kino.pub) service, **built tvOS-first**.

This is a fork of [leoru/kinopub-apple-client](https://github.com/leoru/kinopub-apple-client), which targets
iOS/iPadOS/macOS. The goal of this fork is different: make a proper **Apple TV** app.

A second, actively maintained fork of the same original —
[dungeon-master-xx/kinopub-apple-client](https://github.com/dungeon-master-xx/kinopub-apple-client) —
is tracked as a **read-only remote** (`community`) for technical steals (API models, device
profile, vote/collections, keyless Kinopoisk proxy). We do **not** rebase onto them: histories
diverged (~100 of our commits vs ~200 of theirs) and we own the UI. See
[docs/en/community-fork.md](docs/en/community-fork.md).

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
| tvOS 26+ | **Primary** | Builds and runs. Shared `.sidebarAdaptable` TabView chrome (Rivulet-style). Home is rebuilt; detail page and player still to go. |
| iOS / iPadOS 26+ | Secondary | Works (inherited from upstream). Same TabView; bottom tab bar on iPhone. Kept building, not designed for. |
| macOS 26+ | Secondary | Works (shared `.sidebarAdaptable` TabView sidebar). Kept building, not designed for. |

Non-goals for now: analytics/crash reporting (Firebase has been removed), Downloads on tvOS, and any
custom theming that fights the platform HIG.

## Requirements

- Xcode 16
- Swift 5.9
- Deployment targets: tvOS 26.0, iOS 26.0, macOS 26.0 — matches Rivulet/Silo, no reason to hold back
  from the newest APIs (Liquid Glass included) for an old floor nothing requires
- Local packages (`KinoPubUI` / `Backend` / `Kit` / `Logging` / `Metadata`) also declare
  `.macOS(.v26) / .iOS(.v26) / .tvOS(.v26)` (`swift-tools-version: 6.2`, language mode 5)
- **Dark appearance only** for now (`.preferredColorScheme(.dark)` + `UIUserInterfaceStyle = Dark`).
  Light comes back as a deliberate pass once dark is good.

There is a **single multiplatform target** (`KinoPubAppleClient`, product name `KinoPub`) covering all
platforms. Platform differences live in `#if os(tvOS)` / `#if os(iOS)` / `#if os(macOS)` blocks — please
do not add a second target.

```
open KinoPubAppleClient.xcodeproj
# then pick the "Apple TV" destination
```

## What works today

- Device-code authorization against the kino.pub API, tokens in the Keychain, shown on a full-screen
  activation page modelled on the system AirPlay-code screen (`Views/Auth/`): material background,
  the code split into per-character tiles, no dismiss affordance, and a spinner underneath while an
  expired code is silently replaced
- Catalog browsing: `hot` / `fresh` / `popular` per content type, paginated
- Search, bookmarks (folders + items), item details, seasons and episodes
- Playback with resume ("continue watching" prompt) and watch-mark reporting
- **The player is presented, not pushed, off tvOS**, and off tvOS it is nothing but the system player.
  macOS gives it its own window the way the stock TV app lifts a film out of the page it was on: the title
  bar carries the name and the close button, Escape leaves, ⌘W closes the film rather than the app. It
  opens at 16:9 so a wide short window doesn't fill with black bars, and it's off the Window menu — the
  only way in is pressing Play. iOS lets `AVPlayerViewController` take itself full-screen, which is the
  only way it draws the system Done button. Automatic window tabbing is off app-wide
  (`AppDelegate.applicationDidFinishLaunching`): AppKit was merging the player into the library window's
  tab group, where it wore that window's back button and ⌘W closed everything
- **Playback starts first; the dub relabel rides along.** The rewritten master is served to AVPlayer from
  memory through `HLSMasterResourceLoader` (custom scheme, one request, children straight from the CDN).
  It replaced writing the master to a `file://` temp path — AVFoundation never finishes loading a
  file-URL master whose media is remote, so every film spun forever while trailers, which skip the
  rewrite, played fine. A failed fetch now fails the item instead of hanging, and the player always shows
  a spinner with Cancel, or the error with Close (`PlayerManager.playbackState`)
- Downloads and offline playback (iOS/iPadOS/macOS only) — mp4 with resume-across-relaunch,
  reject of tiny HTTP error bodies, iOS HLS `.movpkg` (all dubs/subs), season queue, player
  prefers a present local file over streaming. No download UI on tvOS.
- **Subtitles are the system's off tvOS.** The master playlist carries every kino.pub subtitle as a real
  HLS rendition, so the system player lists and draws them; we add nothing. On tvOS only, sidecar SRT is
  parsed into synced cues and drawn as an overlay, picked from the transport-bar menu — **English by
  default**, preferring non-CC/SDH, toggles in Profile → Playback
- **Dual subtitles** (two tracks stacked) — tvOS only, for the same reason
- Tap-a-word translation on pause is **parked**, not shipped: `SubtitleTranslatePanel.swift` and
  `SubtitleTrackPickerView.swift` build but nothing presents them (see the note at the top of each)
- **Home opens with a contained 16:9 banner shelf** (up to six cards sampled from the
  catalog rows below): wide backdrop, inset vertical poster with rating badge, titles +
  IMDb/Kinopoisk scores, private `variableBlur` over static art — **no CTAs for v1**,
  **no Netflix-style focus preview**. Banner shelf snaps two-up via `scrollTargetBehavior(.viewAligned)`.
  Phone fills width; tvOS / macOS / iPad landscape keep ~2 columns so cards stay padded,
  not full-bleed. Home uses system material + `backgroundExtensionEffect` under the sidebar.
  The old `showsFeaturedPreview` path is deleted. See
  [modernization plan D1](docs/en/plans/modernization.md).
- **Backgrounds and type are the system's** (`Color.KinoPub.background` / `.text` / `.subtitle`): black
  and true white on a TV in dark appearance, instead of the old hand-picked #1C202B grey and #B0B1B5
  "white".
- **Loading is Apple-TV-shaped, not skeleton-shaped**: a screen stays empty and shows a plain spinner
  once the wait is noticeable (300 ms on listings, 700 ms on an item page), then fades the content in.
  If an item page's details request fails (TLS / VPN / offline), `UnavailableView` replaces the spinner
  with a short message and a focusable Try Again button.
  Artwork fades up out of a dark tile. `LoadingIndicatorView` in `KinoPubUI` is the one spinner.
  **Search is the exception**: the query field, filter chips and a grid of empty poster tiles are on
  screen from the first frame (filters scroll with the grid, not pinned above it), so the remote
  always has somewhere to land; real cards replace the tiles when the page arrives.
- **Navigation chrome is a shared system `TabView` + `.sidebarAdaptable`** (`TabsNavigationView`):
  sidebar on Mac/TV, bottom tabs on iPhone. Destinations use a single `Route` enum +
  `RouteDestination` registry; zoom transitions (`matchedTransitionSource` /
  `navigationTransition(.zoom)`) on iOS/tvOS from poster/banner/cast sources.
  - **tvOS:** flat tabs — profile at the top (header on tvOS 27+, first tab on 26), then
    Search (`Tab(role: .search)`), For You, Movies, Series, Library. System tab icons; focus
    lands on content, not the sidebar. Re-selecting a tab pops that tab's stack to root.
  - **iOS / iPad:** Search role + Library merge; Downloads stays its own tab.
  - **macOS:** sidebar sections (Browse / Library / Folders) with `TabViewCustomization`, profile
    pinned via `tabViewSidebarBottomBar`.
- **Detail pages use one vertical `ScrollView`** (hero + content) with layout-driven focus —
  the old tvOS offset slideshow / focus bridges are gone.
- **Playback is a single app-scoped `PlaybackSession`** — one `PlayerManager` / stream at a time;
  tab destinations and the macOS player window host the same session.

## Known issues / half-finished

These are real, verified, and up for grabs:

- **The pause panel's focus behaviour is unverified on a real remote.** The word chips now use a
  focus-reactive button style, but nobody has driven it with a Siri Remote yet.
- **Seasons rail focus on a real remote is unverified** after replacing the programmatic
  `focusBridge` with `focusSection` + `defaultFocus` (`SeasonsRailView.swift`). Up from an
  episode should land on the selected season tab; if it lands on a random tab or dead space,
  restore a bridge or add `resetFocus(in:)`.
- **Poster card `.hoverEffect(.highlight)` is unverified on a real remote.** Added so
  `.borderless` binds its lift/specular/tilt to the `AsyncImage` poster
  (`MediaCardView.swift`); needs a Siri Remote check that the system focus effect actually
  appears.
- **The detail page's default focus is unverified on a real remote.** `MediaItemView` names Play with
  `.defaultFocus($focus, .play)`; a headless simulator draws no focus at all, so this has only been
  read, not seen.
- **Poster cards use the native focus effect.** On tvOS the catalog rows, the grid and the related
  rail apply `.buttonStyle(.borderless)`, so the system provides the real lift, specular shine and
  remote-tracking parallax. This replaced a hand-rolled `SiriRemoteTilt` (`rotation3DEffect` driven by
  the touch surface as a `GCController` joystick), which faked the tilt, reconfigured the micro-gamepad
  globally, and could never be felt in the simulator anyway — that file is gone. `MediaCardView` reads
  focus from `\.isFocused` so its caption/rating/footer still respond under the system style.
- **The detail page has no on-screen back button**, matching the stock Apple TV app — Back/Menu on the
  remote pops the stack. If that turns out not to fire, it is a real bug, not a design choice.
- **Subtitles don't follow the episode.** `MediaItem.subtitles` returns `videos?.first?.subtitles`, so a
  series always uses the first video's tracks. See `Packages/KinoPubBackend/.../Models/MediaItem.swift`.
- **The player window has not been clicked through since the last round of fixes.** Escape-to-close, the
  16:9 opening size, tabbing being off, and the film's name in the title bar are all read, not seen —
  driving the app from here is blocked (a DerivedData build isn't in the computer-use app list, AppleEvents
  wait on a TCC prompt, `screencapture` has no Screen Recording grant). Same for iOS: that Done both
  closes the presentation and pops the route is reasoned from the delegate contract, not observed.
- **Space doesn't pause on macOS** — reported, and not fixed by this round. With our overlay chrome gone
  the system player should get the key itself; if it still doesn't, the next thing to check is what holds
  first responder inside the window, not to add another hand-rolled shortcut.
- **tvOS player is unverified on a real remote.** `PlayerView` now drives `AVPlayerViewController`
  directly on tvOS (`TVVideoPlayer` in `Views/Player/PlayerView.swift`) — no hand-rolled chrome, the
  Subtitles picker lives in `transportBarCustomMenuItems` (dual tracks + sidecar), audio is left to the
  system picker the HLS stream already provides, and Menu-to-exit is wired through
  `AVPlayerViewControllerDelegate.playerViewControllerShouldDismiss` rather than assumed. Builds and
  reads correctly, but the whole thing — Menu exit, the Subtitles menu, the Up-swipe that takes
  the item page's inline trailer full-screen — has only been read, not driven with a real Siri Remote.
- **Subtitle/Audio buttons are de-duplicated.** The HLS groups made `AVPlayerViewController` draw its
  own Subtitles and Audio controls next to ours. Audio: we dropped our custom menu and kept the system
  picker (our ranker still picks the default, `persistAudioSelectionIfNeeded` remembers a manual switch).
  Subtitles: we kept ours (dual tracks + sidecar) and hid the system one with
  `allowedSubtitleOptionLanguages = []` in `hideSystemSubtitlePicker`. Safe per the Stream survey — every
  kino.pub subtitle is a sidecar SRT (srt × 189, embed × 0, CC × 0), so the system picker could reach
  nothing ours can't. **Needs a real-remote check** that `[]` hides the button rather than showing an
  Off-only one, and that every expected track still appears in our menu.
- **Whether the system Audio picker itself shows the relabeled dub names is unverified.** `NAME=` from the
  master reaches AVFoundation as the option's common-metadata title, but *not* as `displayName` — a
  rendition renamed to "ZZPROBE-ONE" still reported `displayName == "Russian"`. Our own ranking and
  "remember this dub" now read the metadata title (`AVMediaSelectionOption.kinopubTrackName`), so they
  see real names; which of the two AVKit's picker renders on tvOS has only been reasoned about, not seen
  on a screen.
- **kino.pub declares one AUDIO group per video variant, so the system picker lists every dub three
  times.** A master with four dubs publishes `audio1080`, `audio720` and `audio480` groups, and
  `mediaSelectionGroup(forMediaCharacteristic: .audible)` returns all 12 renditions — verified against a
  live master. De-duplicating means picking one group and hiding the rest, which touches which rendition
  the ABR ladder actually plays, so it wasn't done blind.
- **The player's title only shows the series name when reached from the item page.** `Episode` carries
  a `seriesTitle` filled in by `MediaItemHeroView`/`SeasonsRailView` right before playback; the
  standalone season-browsing route (`Routes.season`, opened from Catalog/Search/Bookmarks/Main without
  going through the item page) never had the series name to begin with, so the player falls back to the
  episode's own title there. Plumbing it through means widening `Season`/`Routes.season` — a bigger,
  shared-navigation change than a punch-list fix.
- **Default audio-track ranking shares its ladder with the detail-page Audio column**
  (`AudioTracks` in KinoPubBackend): preferred languages, then A–Z, AD last, kind
  (DUB → MVO → DVO → VO → AVO → Orig), studio A–Z, more channels first. Before play,
  `HLSAudioLabeler` rewrites the HLS master's AUDIO `NAME=` attributes from the API
  (`Video.audios` / `Episode.audios`) so the system Audio picker shows
  "Russian — Dub (Studio)" instead of three identical "Russian" rows. Matching is by
  language order in the playlist; if the CDN drops a codec duplicate the leftover API
  rows are unused. Relabel failure falls back to the CDN master unchanged.
- **Stream survey (DEBUG).** Settings → Diagnostics → Stream survey walks ~40 catalogue items and reports
  what kino.pub actually delivers vs. what the API claims: delivered `hls4` `CODECS`/`CHANNELS`/`VIDEO-RANGE`
  against source `FileInfo.codec` / `VideoAudio`, each codec flagged for AVFoundation playability. Built to
  answer whether an FFmpeg-backed engine (KSPlayer/MPVKit) would buy anything over AVFoundation.
  `Custom/StreamSurvey.swift` + `Custom/HLSManifest.swift`.

  **First run (20 items, 2026-07):** every delivered stream is `avc1` (H.264 8-bit) + `mp4a` (AAC), SDR,
  ≤1080p, 23.976/24 fps — not one codec AVFoundation can't hardware-decode. Downloads are plain MP4;
  subtitles all sidecar SRT. **Verdict: an FFmpeg engine buys kino.pub nothing** — it would software-decode
  what VideoToolbox already does in hardware, and cost the native transport bar, AirPlay, PiP and battery.
  The manifest carries no `CHANNELS` attribute (273/273 absent), which is why the audio-default ranker
  still has to read channel counts off the dub label. An FFmpeg engine only becomes worthwhile if/when a
  generic-IPTV / m3u8 wrapper lands, where source codecs are arbitrary (that is UHF's world, not ours yet).
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
- **Opening an item by id starts with a bare background.** Rows built from the watching/history
  endpoints route by id (`MainRoutes.detailsById`), so there is no poster to wash the page with until
  the details land; routes that carry the whole `MediaItem` seed `MediaItemModel(knownItem:)` and
  colour the page immediately.
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
- **The watchlist leads Saved** — `/v1/watching/serials?subscribed=1`, above every folder, in the
  order the API returns it: whatever got a new episode most recently is first. Following a show for
  new episodes is the point of saving anything; a folder of films abandoned half-way is not. Cards
  carry the "+12" badge and the resume bar, and the row is dropped when the watchlist is empty.
- **Home** is rows, not a grid. First is a **horizontal shelf of contained 16:9 banner
  cards** (up to six, sampled from the shelves below; static art, no CTAs), then
  **Continue watching**, then category/collection rows. Not a Netflix-style focus preview
  of the selected shelf card. See [modernization plan D1](docs/en/plans/modernization.md).
- **Continue watching is a landscape row** — wide still with a play glyph and resume bar on the
  image, title + "S2, E5 · 42 min" in the caption below (episode-card layout). Long-press for the
  context menu — no ⋯ button on the card.
- **Continue watching merges unfinished + watchlist + recent history**, ordered by intent: recently
  started (played this week), then watchlist titles with new episodes, then the rest of the watchlist,
  then other unfinished. Most recently played first within each group.
- **Poster cards carry one combined score** in the top-left (detail pages show the two sources
  separately instead, where there is room): the average of IMDb and Kinopoisk when
  both rated it, otherwise whichever did, hidden when neither. Colour by tier — gold with laurel wings
  at 8.0+, green from 7.0, grey from 6.0, red below. The tier follows the *displayed* value, so a card
  reading "8.0" always gets the gold treatment.
- **Detail page** leads with full-bleed hero artwork that may give way to a **muted trailer**
  (when the API provides one); title, metadata and plot sit over Music/Journal-style **variable
  blur** on static art (plus a subtle gradient if needed). **tvOS/macOS: no blur over video**;
  **iPhone/iPad: blur OK over video too**. Then one continuous rail of every episode across
  seasons (tabs scroll to a season rather than swapping the list), opening on the first
  unfinished episode. Season tabs and the Ratings label stay hidden while the hero/trailer
  owns focus. Native tvOS buttons — no tiny iOS-sized controls.
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
- Detail page: full-bleed hero with private `variableBlur` (Metal shader removed), the trailer
  playing muted behind the artwork, native-style action buttons (white Play pill + circular
  secondaries — not glass on hero), season tabs over a rail of episode stills
- Tabs: Search · Home · Movies · Series · Saved · Settings, icon-only where it should be
- Combined score badges on posters, separate IMDb/Kinopoisk marks on detail pages
- White accent throughout; the site's green is gone
- Native tvOS parallax focus effect on poster cards via `.buttonStyle(.borderless)` —
  the system's lift, specular shine and remote-tracking parallax, not a hand-rolled tilt
- Long-press menus on Continue Watching and episode cards; Continue Watching merges watchlist +
  recent history (recently started → new episodes → watchlist → rest)
- **UI modernization Phase 2:** `ShelfMetrics` proportional ~6-column posters,
  landscape cards use episode-rail caption layout, Metal ProgressiveBlur replaced with private
  `variableBlur` overlay — see [modernization plan](docs/en/plans/modernization.md)
- **UI modernization Phase 3 (Home banner, partial):** contained 16:9 banner shelf on Home;
  Netflix `showsFeaturedPreview` path deleted. Detail-page hero/focus polish still open.

### Phase A — Plan-minimum: parity with what I already use

Nothing exotic. A working, good-looking client that does what microiptv does.

- [x] **Library browsing in the Search tab**, matching microiptv's Library:
  - all seven sorts, recently added by default. `kinopoisk_rating` and `imdb_rating` are not in the
    docs but the service accepts and orders by them — verified against live responses
  - dropdown filters: type, genre, country, release decade
  - pickers fed by `/v1/genres` and `/v1/countries`
- [x] **Wire the Watched and Bookmark buttons** — Watched hits `/v1/watching/toggle`; Bookmark opens
  the account's folders and toggles membership via `/v1/bookmarks/toggle-item`
- [x] **Long-press context menus on Continue Watching and episode cards** — Go to Show/Movie,
  Hide from Here (`/v1/history/clear-for-item` / `clear-for-media`), Mark as Watched (one episode
  for series), Browse History / Browse Watchlist when the title belongs there. Episode rails reuse
  the same landscape `MediaCardView` as Continue Watching
- [ ] Paginate home rows; cache them so returning to the tab doesn't refetch everything
- [x] **tvOS player chrome is native** — `AVPlayerViewController` driven directly, Subtitles/Audio in
      the transport bar's own menu, no hand-rolled buttons left to fight it (unverified on a real
      remote, see Known issues)
- [ ] Fix the remaining player issue under Known issues: subtitles don't follow the episode
      (`MediaItem.subtitles` always reads the first video's tracks) — CC/forced detection is done:
      `SubtitleTracks` matches markers as whole words and treats forced as its own flag, never a
      default

### Phase B — All of kino.pub's data

microiptv leaves a lot on the table. We shouldn't.

- [x] **The trailer plays behind the hero artwork** — muted, a beat after the page settles, filling
      the frame with no transport chrome, dropping back to the artwork when it ends
- [ ] Trailers on the detail page as a proper section, not only the hero takeover
- [x] Awards — via Kinopoisk Unofficial (see Phase C½), not kino.pub's own payload
- [ ] Collections UI — backend is ready (`CollectionsService`, `GET /v1/collections` + `/view`)
- [x] **Every production country**, not just the first — microiptv shows one
- [x] Ratings section: IMDb and Kinopoisk with vote counts. kino.pub's own thumbs up/down tally is
      commented out in `MediaItemRatingsSection` — it reads empty on everything we have looked at
- [ ] Cast a kino.pub thumbs vote (`GET /v1/items/vote`, `UserActionsService.vote`) + show own vote state
- [x] Cast and crew as round portraits, each opening that person's credits (`/v1/items?actor=`,
      `?director=` — the web client's `mode=actor` search). Person page: null-tolerant listing
      decode, LoadFailed/empty/retry, cast photo + TMDB person bio in a scrollable hero
- [x] Information · Translation · Audio columns, stacking when the display is narrow
- [x] Synopsis as a focusable panel that opens the full text, rather than expanding in place
- [x] Cast photos and character names — via TMDB (`KinoPubMetadata`), matched by `MediaItem.imdb`.
      Kinopoisk Unofficial still planned for Russian character names / awards
- [ ] Sweep the rest of the payload (quality, AC3, age rating) — `quality`/`ac3` decode already;
      filter facets for 4K/HD/AC3/KP/IMDb min are client-side on `LibraryFilter` (server ignores those
      query params); UI chips still to wire
- [x] **Similar items** — horizontal "More like this" rail on the detail page
      (`GET /v1/items/similar?id=`), before Information so tvOS focus can reach it. Prefer this over
      the community fork's "same genre" approximation.

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

### Phase C½ — External metadata (TMDB + Kinopoisk Unofficial)

Cast photos, character names, title logos and episode air dates come from **TMDB** through
`Packages/KinoPubMetadata` and a Cloudflare Worker proxy (`workers/tmdb-proxy/`). Matching is by
`MediaItem.imdb`. Set `TMDBProxyBaseURL` in `Info.plist` after deploying the worker.

**Kinopoisk API Unofficial** (`kinopoiskapiunofficial.tech`) is live as a second, per-user
`MetadataSource` — each user pastes their own key in Settings (Profile → Kinopoisk on iOS/macOS,
Profile → Kinopoisk on tvOS), validated on entry, stored in its own Keychain service so a kino.pub
logout doesn't wipe it. It's a third-party service scraping Kinopoisk's data, not an official
Kinopoisk product — confirmed no official API issues consumer keys at all. Client-only for now: no
backend of ours is involved, no data leaves the device. Free tier caps at 500 requests/day per key
(confirmed live via the API's own error message) — plenty for a single user browsing normally, not
enough for any kind of bulk pull on one key.

**Keyless fallback (from the community fork):** `KinopoiskProxySource` always talks to
`https://kpapp.link/kpapi/films/<kinopoiskId>/{facts,reviews,staff,images}` with **no API key**.
That's why the dungeon-master-xx Mac build shows facts/reviews/stills without any Settings —
verified live (HTTP 200, no auth). We keep the keyed source for awards + richer data when the user
has a key; the proxy fills gaps otherwise. Actor portraits without TMDB can use
`ActorImageProvider` (`m.pushbr.com/actors/<md5(ru name)>.jpg`). Third-party proxies can die;
sections stay empty when they do.

- [x] TMDB package + proxy + cast photos / character names / title logos
- [x] TMDB person details on the credits page (`/3/person/{id}` — bio, birthday, place of birth)
- [x] Episode air dates + upcoming unplayable (Phase F via TMDB)
- [x] TMDB tagline, budget/revenue, production companies / TV network — plumbed into
      `TitleMetadata` (already part of the response TMDB was sending us, just never decoded before),
      not yet surfaced in any UI section
- [x] Kinopoisk Unofficial: per-user API key in Settings, validated (distinguishes invalid key from
      "valid, but today's quota is used up"), own long-TTL (90-day) cache
- [x] Kinopoisk Unofficial: awards, photo/stills gallery, "facts" section, Russian character names
      merged into the existing cast rail — all as new detail-page sections, hidden when empty
- [x] Confirmed keyed, not keyless — `X-API-KEY` header, free tier 500 requests/day
- [x] Keyless kpapp.link proxy (`KinopoiskProxySource`) for facts/stills/staff/reviews without a key
- [ ] Reviews UI section on the detail page (`TitleMetadata.reviews` is ready from the proxy)
- [ ] Kinopoisk Unofficial: premiere dates — not implemented
- [ ] Kinopoisk Unofficial: box office — the API exposes it (`/films/{id}/box_office`), not wired
      into the live per-user source yet (TMDB's own budget/revenue shipped instead, see above)
- [ ] Kinopoisk Unofficial: deeper person-bio page enrichment (birthday, biography, spouses via
      `/staff/{staffId}`) — deliberately deferred; needs a second person-id slot alongside
      `CastMember.tmdbPersonId`, kino.pub has no native person id to key off of today
- [ ] Surface TMDB's tagline / box office / production company logo somewhere on the detail page
      (data is ready, no UI yet)
- [ ] "Donate" fetched Kinopoisk data back to a shared backend so it isn't gated by each user's own
      500/day — explicitly postponed, no backend exists for this yet; keyless proxy already removes
      the hard gate for facts/stills/reviews

See `tools/kinopub-snapshot/` and `tools/kinopoisk-metadata/` for the offline side of this: a local
snapshot of kino.pub's own catalog plus a separate bulk Kinopoisk-metadata puller (own API key, own
500/day budget, unrelated to what ships in the app) — building toward a locally cached, matched
metadata library independent of any one third-party service's rate limits.

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

- [x] Show air dates on episode cards, including episodes not out yet ("Ep 6 · 14 Aug") — TMDB seasons
- [x] Mark upcoming episodes as unplayable rather than hiding them
- [x] Source: TMDB by IMDb id via `KinoPubMetadata` (kino.pub still has no air dates)

### Later
- [ ] TV channels / Sport UI — backend ready (`GET /v1/tv` → `fetchTVChannels`); EPG is external
      XMLTV in the community fork, not kino.pub — port only when we surface Sport
- [x] **Viewing history screen** — reachable from Continue Watching's context menu (not a tab yet)
- [ ] Top Shelf extension


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
- `/v1/watching/serials` carries **no date of any kind** — only `total`, `watched` and `new` — but it
  arrives sorted by the item's `updated_at`, newest first. Checked against `/v1/items/{id}` for all 14
  entries of a live watchlist: the order matched `updated_at` descending exactly, from 2026-07 down to
  2018-09. So Saved keeps that order as-is; sorting by `new` (or anything else we can see) buries the
  show that got an episode yesterday under a finished one with 171 unwatched.
- A bookmark folder's `updated` tracks its **contents**, not views — reading the folder repeatedly
  leaves it alone, and `/v1/bookmarks/{id}` echoes the same value under `folder`. The items it
  returns carry no per-membership date, so `updated` is the only way to order folders by when
  something was last added to them (`Bookmark.recentlyUpdatedFirst`).

Where a payload shape matters, a decoding test pins the real JSON (see `HistoryEntryTests`) so an
upstream change fails loudly instead of silently emptying a row.

**Already wired** (`Packages/KinoPubBackend/Sources/KinoPubBackend/Requests/`):
`/v1/items/{hot,fresh,popular}`, `/v1/items/search`, `/v1/items/{id}`, `/v1/items/similar`,
`/v1/items/vote`, `/v1/user`, `/v1/bookmarks`, `/v1/bookmarks/{id}`, `/v1/watching`,
`/v1/watching/movies`, `/v1/watching/serials`, `/v1/watching/marktime`, `/v1/watching/toggle`,
`/v1/history`, `/v1/history/clear-for-item`, `/v1/history/clear-for-media`, `/v1/genres`,
`/v1/countries`, `/v1/items` (library filters plus `actor`/`director`; rating/quality facets are
**client-side** — see `LibraryFilter.clientSideMatches`), `/v1/collections`,
`/v1/collections/view`, `/v1/tv` (channels service; no Sport UI yet), `/v1/device/info`,
`/v1/device/{id}/settings` (HEVC/4K/HDR/mixedPlaylist auto-synced on authorize), device-code auth.

**Available, not yet wired:**

| Endpoint | Use |
| --- | --- |
| `GET /v1/items` | Still unused there: `finished`, `letter` (and server-side `quality`/`conditions` are no-ops) |
| `GET /v1/types` | Content-type reference for filters |
| `GET /v1/items/comments` | Title comments (community has it; not ported yet) |

## App structure

Swift Package Manager, one app target plus four local packages:

- `KinoPubAppleClient` — the app target; all shared UI and app logic
- `KinoPubUI` — reusable SwiftUI components (cards, buttons, poster styles)
- `KinoPubKit` — shared business logic (downloading, file storage)
- `KinoPubBackend` — networking layer and API models
- `KinoPubLogging` — small OSLog extensions

Inside the app target:

- `App` — application lifecycle
- `Views` — SwiftUI views grouped by feature (`Main`, `MediaItem`, `Player`, `Bookmarks`, `Downloads`, `Profile`, `Root`, `macOS` settings)
- `Services` — API-backed services (content, user, auth, downloads, keychain)
- `States` — navigation, auth and error state objects
- `Context` — `AppContext` dependency container
- `Custom` — assorted helpers
- `Resources` — assets and localizations

## Third-party libraries

- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) — token storage
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
