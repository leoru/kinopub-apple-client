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
- **Stream survey:** kino.pub deliveries surveyed were AVFoundation-friendly H.264/AAC — **no FFmpeg
  engine** for core playback. That survey does not globally ban capability badges (4K/HDR) when item
  and device flags support them.
- Detail ambient muted trailer is **off on tvOS** (still + scrims + blurred poster wash). It may
  return with a dedicated hero pass.
- A player rewrite is out of scope. Skips and Up Next are thin conveniences layered on system API.

## Known bugs and traps

- **Resume race:** `PlayerView.onAppear` → `fetchWatchMark` → seek. And resume currently reads the
  wrong episode in `PlayerManager`.
- **SRT fetch needs encoding detection** — Russian subtitles are routinely windows-1251.
- **Cue lookup is a linear scan** over ~2000 cues several times a second; it wants a binary search
  plus a cursor.
- `HLSAudioLabeler` writes a temp `.m3u8` per launch into `tmp/kinopub-hls` and never cleans up.
- Two periodic observers, and `currentPlaybackTime` republished four times a second.
- **iOS PiP and background audio need an `AVAudioSession` `.playback` category plus
  `UIBackgroundModes: audio`.** `allowsPictureInPicturePlayback` alone stops at backgrounding, and
  the ringer switch can kill sound.
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
