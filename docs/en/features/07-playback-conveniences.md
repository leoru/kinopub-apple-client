# 07 — Playback conveniences

**Status:** P0 mostly done (metadata off tvOS, custom overlay panel gone, macOS window routing fixed,
`AVPlayerView` bridge on macOS). Info tabs / Up Next / chapters (tvOS `customInfoViewControllers` /
`AVContentProposal` / `navigationMarkerGroups`) and the P1/conveniences sections below are still open.  
**Goal:** Playback memory, skip intro/recap/credits, and Up Next — **without** rewriting the native
player.

## Accepted behavior

- Native `AVPlayerViewController` remains the chrome — and it has to be **populated**, not sat
  beside. Title, subtitle, description, artwork, Info tabs, Related, Skip, Up Next, chapters,
  playback speed and PiP are all AVKit surfaces with real API. We fill those. We do not draw our own
  version of anything AVKit already renders.
- macOS plays in **its own window**, the way the stock TV app takes a film out of the page it was on.
  The player is never a destination inside the main window — sidebar and player on screen together is
  a bug, not a layout.
- Remember audio (and already: subtitle) picks per show when possible.
- Skip / Up Next use the system affordances (`contextualActions`, `AVContentProposal`) before any
  custom overlay is considered.
- End-of-playback policy (auto next season vs stop) needs an explicit Settings decision before coding.

## P0 — use the native player surfaces (before any new convenience)

This comes first, ahead of skip heuristics, TheIntroDB and Up Next data. What exists today is a
system player with almost nothing handed to it plus our own panel drawn on top, which is exactly what
[apple-native-design](../policies/apple-native-design.md) forbids.

### Availability, verified against the 27.0 / 26.0 SDK headers (Aug 2026)

Do not plan iOS or macOS work around the tvOS-only properties — they are `API_UNAVAILABLE`, not
merely undocumented.

| Surface | API | tvOS | iOS | macOS |
| --- | --- | --- | --- | --- |
| Title / subtitle / description / artwork | `AVPlayerItem.externalMetadata` | yes | yes (12.2+) | **absent** |
| Info-panel tabs (Related / Recommended / Bonus) | `customInfoViewControllers` | 15+ | no | no |
| Info-panel actions, max 2 | `infoViewActions` | 15+ | no | no |
| Skip Intro / Recap pill | `contextualActions` | 15+ | no | no |
| Up Next card at the tail of an episode | `AVContentProposal` + `contentProposalViewController` | 10+ | no | no |
| Chapters | `AVPlayerItem.navigationMarkerGroups` | 9+ | no | no |
| Transport-bar custom menu | `transportBarCustomMenuItems` | 15+ | no | no |
| Subtitle overlay hosting / layout guide | `customOverlayViewController`, `unobscuredContentGuide` | 13+ / 11+ | no | no |
| Playback speed | `speeds` / `selectedSpeed` | 16+ | 16+ | `AVPlayerView.speeds` (13+) |
| Picture in Picture | `allowsPictureInPicturePlayback` | 14+ | 9+ | `AVPlayerView` (10.15+) |
| Custom media-selection schemes | `AVCustomMediaSelectionScheme` | 26+ | 26+ | 26+ (no AVKit UI) |

So: the rich Info / Related / Up Next experience is a **tvOS** deliverable. On iOS the honest native
scope is `externalMetadata` + speed + PiP; on macOS the title lives in the window title bar and
Now Playing, because `externalMetadata` does not exist there at all.

### Work

- [x] **Delete the custom centre panel.** `PlayerView.playbackStateOverlay` drew our own title,
  spinner and a `Cancel` / `Close` button over the video. Exit belongs to the system: the window close
  button on macOS, Done on iOS, Menu on tvOS — removed the overlay for `.preparing` / `.ready`
  entirely. **Decided:** a failure shows a system alert over the player and we stay in the player —
  it no longer draws its own panel either, and no navigation happens on the way there.
- [x] **`externalMetadata` off tvOS too.** `PlayerManager.attach(to:)` and
  `configureExternalMetadata()` sat inside `#if os(tvOS)`, so the iOS player showed no title,
  subtitle, description or artwork at all. Moved the metadata build into a shared
  `#if os(iOS) || os(tvOS)` extension, called from `preparePlayback()` on both. `MPNowPlayingInfoCenter`
  on macOS is still open — no `externalMetadata` equivalent exists there and nothing populates Now
  Playing yet.
- [ ] **Info tabs on tvOS** via `customInfoViewControllers`: Related (we already load TMDB
  recommendations in `MediaItemModel.externalMetadata`), and Episodes / Up Next for a series. Set
  each controller's `title` and a consistent `preferredContentSize` height.
- [ ] **`infoViewActions`** for the two actions worth having — Watchlist toggle, From beginning.
- [ ] **Up Next natively** with `AVContentProposal` (`contentTimeForTransition`,
  `automaticAcceptanceInterval`, preview image) and
  `playerViewController(_:shouldPresent:)` / `didAccept` / `didReject`, driven by the next episode
  from `SeasonsRailView`'s existing next-episode logic. This is the system's own end-of-episode card;
  it also keeps Now Playing correct.
- [ ] **Chapters** via `navigationMarkerGroups` once we have any marker source (SRT gap heuristic,
  TheIntroDB).
- [ ] **Subtitle overlay inside the controller**: `customOverlayViewController` +
  `unobscuredContentGuide`, styling from `MediaAccessibility`, not a SwiftUI sibling in a `ZStack`
  with hardcoded 34/22pt.
- [ ] Re-check `allowedSubtitleOptionLanguages = []`: hiding the system picker is only justified while
  our menu is strictly a superset. `AVCustomMediaSelectionScheme` (26+) may let sidecar SRT tracks
  live in the *system* subtitles menu instead — evaluate before building more of our own menu.

### macOS presentation (bug, not polish)

- [x] The player must always open in the dedicated window. `MediaItemHeroView`'s primary Play button
  and Trailer menu item used `NavigationLink(value:)` instead of `PlayerLink`; `DownloadsView`'s two
  play rows did too. Both now go through `PlayerLink`. Card context-menu Play
  (`MediaCardMenuCoordinator.play` → `navigationState.push`) is fixed at the root:
  `NavigationState.push` redirects `.player` / `.trailerPlayer` into `PlaybackWindowState` on macOS
  instead of appending to a tab's stack, so every current and future push-based Play entry point is
  covered without having to audit call sites again. `RouteDestination` also guards the two cases on
  macOS (`MacPlayerRouteGuard`) — opens the window and pops itself if a player route ever reaches the
  stack anyway, with an `assertionFailure` in DEBUG so a regression is loud.
- [x] Replaced SwiftUI `VideoPlayer` on macOS with a thin `AVPlayerView` bridge (`MacVideoPlayer` in
  `PlayerView.swift`) — `speeds`, `allowsPictureInPicturePlayback`, `showsFullScreenToggleButton`,
  `showsSharingServiceButton` are all set there now. `controlsStyle` left at the system default.
- [x] Window sizing / aspect: the film opens at a sensible 16:9 size and the title bar carries the
  name (already wired through `navigationTitle`), Escape and ⌘W both leave. (Predates this pass —
  `KinoPubAppleClientApp.swift`'s `defaultWindowPlacement`.)

## P1 — parity with the player kino.pub already has

Before new inventions. These are things a user of the current client will notice missing.

- [x] **Playback speed** on macOS (`AVPlayerView.speeds`, set to `systemDefaultSpeeds` in
  `MacVideoPlayer`; iOS/tvOS already defaulted to it).
- [ ] **PiP that actually survives backgrounding on iOS.** The controller sets
  `allowsPictureInPicturePlayback`, but the app configures no `AVAudioSession` category and has no
  `UIBackgroundModes: audio` — so PiP and audio stop when the app leaves the foreground, and the
  ringer switch can kill sound. Add the audio session (`.playback`) and the background mode, then
  `canStartPictureInPictureAutomaticallyFromInline` on iOS.
- [ ] Verify AirPlay / Now Playing / Control Center show the right title and artwork on every platform
  once metadata is fed.

## Conveniences (after P0 / P1)

- [x] Per-show subtitle track memory (`SubtitleTrackReference`)
- [x] Dual subtitles option (tvOS) — parked defaults OK
- [ ] Per-show audio track memory
- [ ] Fix subtitles-follow-episode bug (`MediaItem.subtitles` reads first video only)
- [ ] Skip data — subtitle-gap heuristic first, fed into `contextualActions` (see P0)
- [ ] TheIntroDB (IMDb/TMDB keys) cached per episode
- [ ] AniSkip for anime once MAL/AniList match exists
- [ ] End-of-playback behavior + Settings (the card itself is `AVContentProposal`, see P0)
- [ ] Resume prompt default documented (blocking vs always-continue)

### Correctness bugs (moved from the modernization plan)

- [x] **Two players at once on macOS.** `PlaybackSession` is the one real film/trailer player
  and was already correct. The bug was a second, independent `AVPlayer` — the hero's own ambient
  preview (`TrailerPreviewModel`, muted, autoplays behind the artwork). Off macOS it stops for
  free: pushing the system player onto the stack fires `MediaItemView.onDisappear`. macOS opens a
  *separate* window instead (see "macOS presentation" above) — the detail page never disappears —
  so the ambient preview kept animating behind the new window for as long as it stayed open, and
  the "Trailer" action specifically meant the same clip playing twice, unsynced (ambient muted copy
  behind, real unmuted copy in the new window). Fixed by having `MediaItemView` observe
  `PlaybackWindowState.shared.request` on macOS and call `trailer.stop()` the moment a window
  request goes out — the same "stop, don't try to resume" contract `onDisappear` already applies
  everywhere else. **General rule this exposes:** any ambient/preview player outside
  `PlaybackSession` has to be wired to the same "a real playback session started elsewhere" signal;
  it does not get this for free just because `PlaybackSession` itself is a proper singleton.
- [ ] **macOS AVKit chrome is the public surface, not necessarily what Apple's own apps show.**
  `MacVideoPlayer` (`AVPlayerView`) gives real `speeds` / PiP / fullscreen-toggle / sharing, but
  TV.app and Music.app on macOS visibly draw controls `AVPlayerView`'s documented API doesn't
  expose (layout, iconography, some transport affordances) — flagged, not investigated: nobody has
  yet compared `AVPlayerView.controlsStyle` variants side-by-side against the real apps to say
  which parts are actually reachable public API dressed differently vs. private/inaccessible.
  Needs an actual side-by-side pass (screenshots of TV.app/Music.app vs. each `controlsStyle`) before
  concluding anything is or isn't reachable — do not guess at private API from memory.
- [ ] **Resume race:** `PlayerView` `.onAppear` → `fetchWatchMark` → seek
- [ ] **Resume reads the wrong episode** in `PlayerManager`
- [ ] SRT fetch needs encoding detection + validation (Russian subs are routinely windows-1251)
- [ ] Cue lookup: binary search + cursor instead of a linear scan over ~2000 cues several times a
  second

### Player performance and lifetime

- [ ] Drop the second periodic observer; stop republishing `currentPlaybackTime` four times a second
- [ ] `PlayerTimeObserver` fires its callback on `.global(qos: .userInteractive)`
- [ ] `Task.detached(priority: .utility) { [unowned self] … }` in `PlayerManager`
- [ ] `HLSAudioLabeler` writes a temp `.m3u8` per launch into `tmp/kinopub-hls` and never cleans up
- [x] `BestVideoQualityFinder` uses window-scene `nativeBounds` (pixel height) instead of deprecated
  `UIScreen.main.bounds`, so 4K Apple TVs can select a 2160p ladder

Detailed rationale and file:line references stay in
[`modernization.md`](../plans/modernization.md).

## Out of scope

Full custom player, FFmpeg engine, language-learning tap-a-word (stage 08).
