---
name: player-avkit
description: Working on playback — the AVKit player, its metadata and info panels, skip / Up Next / chapters, subtitles and audio tracks, playback routing, resume, or the macOS player window. Use before adding anything on top of the system player, and before planning a player feature for a platform.
---

# Player and AVKit

**The native controller is the chrome, on every platform.** Custom transport bars fight AirPlay, Now
Playing and accessibility. But using the system player is not the same as **populating** it —
everything the stock TV app shows over video (title, description, artwork, Info tabs, Related, Skip
pill, Up Next card, chapters, speed) is AVKit API you fill in, not chrome you rebuild.

The player draws no chrome of ours: no custom title, no Cancel button, no centre panel. Exit is the
window close button, Done, or Menu.

## What exists where

Verified against the iOS/tvOS 27.0 and macOS 26.0 SDK headers (Aug 2026). The tvOS-only entries are
`API_UNAVAILABLE` elsewhere — a plan that promises them on iOS or macOS is wrong on arrival.

| Surface | API | tvOS | iOS | macOS |
| --- | --- | --- | --- | --- |
| Title / subtitle / description / artwork | `AVPlayerItem.externalMetadata` | yes | 12.2+ | **absent** |
| Info-panel tabs | `customInfoViewControllers` | 15+ | no | no |
| Info-panel actions (max 2) | `infoViewActions` | 15+ | no | no |
| Skip Intro / Recap pill | `contextualActions` | 15+ | no | no |
| Up Next card | `AVContentProposal` + `contentProposalViewController` | 10+ | no | no |
| Chapters | `AVPlayerItem.navigationMarkerGroups` | 9+ | no | no |
| Transport-bar custom menu | `transportBarCustomMenuItems` | 15+ | no | no |
| Overlay hosting / safe layout | `customOverlayViewController`, `unobscuredContentGuide` | 13+ / 11+ | no | no |
| Playback speed | `speeds` / `selectedSpeed` | 16+ | 16+ | `AVPlayerView.speeds` 13+ |
| Picture in Picture | `allowsPictureInPicturePlayback` | 14+ | 9+ | `AVPlayerView` 10.15+ |
| Custom media-selection schemes | `AVCustomMediaSelectionScheme` | 26+ | 26+ | 26+ (no AVKit UI) |

So the rich Info / Related / Up Next experience is a **tvOS deliverable**. On iOS the honest native
scope is `externalMetadata` + speed + PiP. On macOS there is no `AVPlayerViewController` and no
`externalMetadata` at all: the AppKit surface is `AVPlayerView`, the title belongs to the window
title bar and `MPNowPlayingInfoCenter`, and SwiftUI's `VideoPlayer` exposes none of `speeds` /
`controlsStyle` / PiP — that needs an `NSViewRepresentable`.

## Ours

- **One app-scoped `PlaybackSession` / `PlayerManager`.** Do not allocate a manager per route.
- **Leaving the player ends the film.** The session outlives the screen on purpose, so nothing
  stops the stream unless the exit path says so: `PlaybackSession.stop(_:)` takes the manager the
  screen was showing (a route can tear down after the next film already claimed the session) and
  `tearDownForReplacement` does the real work — `replaceCurrentItem(with: nil)`, not `pause()`,
  which leaves a loaded item and a live resource loader behind. The one exception is an active
  PiP window: that is the viewer keeping the film, not closing it.
- **The exit signal is not the same on every platform.** tvOS and macOS use `onDisappear`
  (Menu → `playerViewControllerShouldDismiss`; closing the window). **iOS must not** — the view
  gets `onDisappear` when AVKit presents the player, i.e. on the way *in* — so there the signal is
  the host controller's `viewDidAppear` once the presentation is gone (AVKit's dismissal delegate is
  unavailable in the SDK; see the traps below).
- **iOS presents the player, and that is where the close button comes from.** An embedded
  `AVPlayerViewController` draws a transport bar and nothing else; with the navigation bar hidden
  that is a film you cannot leave. `entersFullScreenWhenPlaybackBegins` was supposed to buy the
  presentation and did not, so `PlayerPresentationController` presents it `.fullScreen` outright.
- **`TrackResolver` decides the subtitles on every platform, not only tvOS.**
  `player.appliesMediaSelectionCriteriaAutomatically` is off, because automatic criteria follow the
  system caption settings and the *Automatic* display type exists to put captions up when the media
  is **muted** — a transcription nobody asked for — while knowing nothing about the last episode.
  Off tvOS the resolver's answer is carried to the master's own `SUBTITLES` renditions by
  `SubtitleRenditions` (language + position within that language; no id is shared between the API
  list and the master). **That is not "off": the resolver reads the system setting itself** —
  `.alwaysOn` in Settings › Accessibility means on, and the system caption languages seed the
  language order (`SubtitlePreferences.systemWantsCaptions`). Only the muted reflex is gone; a pick
  in the system menu still wins. Rules: `docs/product/playback-tracks.md`.
- **The audio ledger is still tvOS-only.** Off tvOS the dub is whatever the master marks `DEFAULT`,
  which is `HLSAudioLabeler`'s ranked pick rather than the CDN's — a simpler rule than the resolver's
  scopes and weights. Selecting it through `AudioRenditions` off tvOS is the missing half.
- `externalMetadata` is built once in `PlayerManager.configureExternalMetadata()` under
  `#if os(iOS) || os(tvOS)` and called from `preparePlayback()` — plus again from tvOS's
  `attach(to:)`, for a controller that attaches after the item already exists.
- **Off tvOS: present the player, do not push it.** macOS uses its own 16:9 window; iOS lets the
  system controller go full screen for Done. **Every play entry point goes through `PlayerLink`** —
  a `NavigationLink` to the player route puts the film in the macOS detail column with the sidebar
  still visible, which is a bug, not a layout. `NavigationState.push` redirects player routes into
  `PlaybackWindowState` on macOS so future entry points are covered without re-auditing call sites,
  and `RouteDestination` guards the two cases with an `assertionFailure` in DEBUG.
- **Any ambient/preview player outside `PlaybackSession` must be wired to "a real session started
  elsewhere".** It does not get that for free. Off macOS the hero's muted trailer stops because
  pushing the player fires `onDisappear`; macOS opens a *separate window*, so the detail page never
  disappears and the ambient copy kept playing behind it — the Trailer action meant the same clip
  playing twice, unsynced.
- Subtitles: system HLS renditions off tvOS; tvOS may use a sidecar overlay for dual tracks. Hide the
  duplicate system subtitle button only while our menu is a strict superset.
- Audio: system picker + master `NAME=` relabel via `HLSAudioLabeler`.
- **Which dub and which subtitles a title opens with is `TrackResolver`, not the player.** One pure
  function over a menu + what the scopes remember + settings; scopes are season → title → `anime`
  class → ladder. Do not add a second selection rule beside it, and do not remember a dub by
  rendition name, index or URL — those differ between two episodes of one season. Rules and reasons:
  `docs/product/playback-tracks.md`. `TrackPreferenceStore` owns the ledgers and writes to every
  scope a play teaches; `PlaybackSession` derives `TitleTrackProfile` because genres and countries
  live on the *item* and an `Episode` is not one. `AudioTrackMemory` / `AudioTrackRanker` are
  **deleted** — do not reintroduce a second ranking ladder beside the resolver.
- **Stream survey:** kino.pub deliveries surveyed were AVFoundation-friendly H.264/AAC — **no FFmpeg
  engine** for core playback. That survey does not globally ban capability badges (4K/HDR) when item
  and device flags support them.
- Detail ambient muted trailer is **off on tvOS** (still + scrims + blurred poster wash). It may
  return with a dedicated hero pass.
- A player rewrite is out of scope. Skips and Up Next are thin conveniences layered on system API.

## Known bugs and traps

- **Resume race:** `PlayerView.onAppear` → `fetchWatchMark` → seek. And resume currently reads the
  wrong episode in `PlayerManager`.
- **The app target's Swift module is `KinoPub`, not `KinoPubAppleClient`.** `PRODUCT_NAME` is
  KinoPub and nothing overrides `PRODUCT_MODULE_NAME`, so a test bundle writes
  `@testable import KinoPub`. The target name is not the module name.
- **A witness to a public protocol from another module must be `public`**, even when the
  conformance is internal and used in one file — `extension AVMediaSelectionOption:
  AudioRendition` needs `public var renditionName`. Trimming it to internal fails only on the
  platforms that compile the conformance.
- **A package that builds under `swift test` can still break the app.** `swift test` runs the
  package on **macOS only**, so a symbol fenced `#if os(macOS)` and used unfenced compiles there and
  fails every simulator build — `MediaCardView`'s `isHovered` did exactly that. The tvOS/iOS
  `xcodebuild` jobs are the only thing that catches it; read them before believing green tests.
- **`playerViewControllerDidEndDismissalTransition` is unavailable in the iOS 26 SDK** —
  implementing it fails the build with "cannot override … which has been marked unavailable",
  so AVKit's delegate has nothing to say about Done on a presented player. The exit signal is
  UIKit's instead: the host controller's `viewDidAppear` after the presentation has gone.
  Re-probe the delegate on the next SDK. (Verified on CI, Xcode 26, Aug 2026.)
- **`AVAudioSession.RouteSharingPolicy.longFormVideo` is `API_UNAVAILABLE(tvos)`** — the
  constant does not compile on tvOS at all, so it cannot merely be attempted and caught. The
  policy is fenced to iOS; tvOS takes the plain `.playback` / `.moviePlayback` category.
- **SRT fetch needs encoding detection** — Russian subtitles are routinely windows-1251.
- **Cue lookup is a linear scan** over ~2000 cues several times a second; it wants a binary search
  plus a cursor.
- `HLSAudioLabeler` writes a temp `.m3u8` per launch into `tmp/kinopub-hls` and never cleans up.
- Two periodic observers, and `currentPlaybackTime` republished four times a second.
- **An iOS app that sets no audio session category gets `.soloAmbient`, which the Ring/Silent
  switch mutes by definition** — and the volume keys then move the ringer, so there is no sound
  and nothing that turns any on. That was the silent iPhone player, not the stream.
  `PlaybackAudioSession` sets `.playback` / `.moviePlayback` around every stream, and
  `UIBackgroundModes: audio` is declared per-SDK in the pbxproj
  (`INFOPLIST_KEY_UIBackgroundModes[sdk=iphone*]`, so tvOS and macOS keep their own behavior) —
  which is also the prerequisite `allowsPictureInPicturePlayback` was always missing.
- `AVAssetDownloadURLSession` does not give tvOS the iOS downloads UX — **Downloads stay non-TV**.

## Open questions — do not answer them from memory

- Whether `AVPlayerView.controlsStyle` (`.default` / `.floating` / `.minimal` / `.inline`) can
  reproduce what TV.app and Music.app show on macOS, or whether those apps draw outside
  `AVPlayerView`'s documented surface. Needs a real screenshot-by-screenshot comparison; do not
  guess at private API.
- Whether the AVKit audio picker shows relabeled metadata titles or language-only `displayName`.
- Deduplicating triple AUDIO groups in HLS masters without breaking ABR.
- Real Siri Remote behavior: Menu dismiss, Subtitles menu, up-swipe trailer full screen, dual-sub
  focus.
- Auto / live transcription needing decoded PCM from HLS is largely a **tvOS 27+** concern.
