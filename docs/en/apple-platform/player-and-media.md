# Player and media

## Evergreen

- Prefer `AVPlayerViewController` system chrome on every platform. Custom transport bars fight AirPlay,
  Now Playing, and accessibility.
- Using the system player is not the same as *populating* it. Everything the stock TV app shows over
  video — title, subtitle, description, artwork, Info tabs, Related, Skip pill, Up Next card,
  chapters, speed — is AVKit API you fill in, not chrome you rebuild.

### Customization surface, per platform

Verified against the iOS/tvOS 27.0 and macOS 26.0 SDK headers (Aug 2026). The tvOS-only ones are
`API_UNAVAILABLE` elsewhere, so a plan that promises them on iOS or macOS is wrong on arrival.

| Surface | API | tvOS | iOS | macOS |
| --- | --- | --- | --- | --- |
| Title / subtitle / description / artwork | `AVPlayerItem.externalMetadata` | yes | 12.2+ | **absent** |
| Info-panel tabs | `customInfoViewControllers` | 15+ | no | no |
| Info-panel actions (max 2) | `infoViewActions` | 15+ | no | no |
| Skip Intro / Recap pill | `contextualActions` | 15+ | no | no |
| Up Next / next-episode card | `AVContentProposal`, `contentProposalViewController` | 10+ | no | no |
| Chapters | `AVPlayerItem.navigationMarkerGroups` | 9+ | no | no |
| Transport-bar custom menu | `transportBarCustomMenuItems` | 15+ | no | no |
| Overlay hosting / safe layout | `customOverlayViewController`, `unobscuredContentGuide` | 13+ / 11+ | no | no |
| Playback speed | `speeds` / `selectedSpeed` | 16+ | 16+ | `AVPlayerView.speeds` 13+ |
| Picture in Picture | `allowsPictureInPicturePlayback` | 14+ | 9+ | `AVPlayerView` 10.15+ |
| Custom media-selection schemes | `AVCustomMediaSelectionScheme` | 26+ | 26+ | 26+ (no AVKit UI) |

- macOS has no `AVPlayerItem.externalMetadata` and no `AVPlayerViewController`: the AppKit surface is
  `AVPlayerView`, the title belongs to the window title bar / `MPNowPlayingInfoCenter`, and SwiftUI's
  `VideoPlayer` exposes none of `speeds` / `controlsStyle` / PiP — that needs an `NSViewRepresentable`.
- iOS PiP and background audio need an `AVAudioSession` `.playback` category plus
  `UIBackgroundModes: audio`; `allowsPictureInPicturePlayback` alone stops at backgrounding.
- `AVAssetDownloadURLSession` offline model does **not** give tvOS the same downloads UX as iOS —
  Downloads stay non-TV.
- Auto / live transcription pipelines that need decoded PCM from HLS are largely **tvOS 27+**
  concerns (`Speech` / sample-buffer paths). Treat advanced subtitle intelligence as a late stage.
- Skip intro databases (TheIntroDB, AniSkip) key off IMDb / TMDB / MAL — useful after catalog IDs are
  solid; see feature doc for playback conveniences.

## Project decisions

- `AVPlayerItem.externalMetadata` (title, subtitle, description, genres-as-type, poster
  artwork) is populated on iOS and tvOS from `PlayerManager.configureExternalMetadata()` —
  shared code under `#if os(iOS) || os(tvOS)` in [PlayerManager.swift](../../../KinoPubAppleClient/Views/Player/PlayerManager.swift),
  called from `preparePlayback()` (and again from tvOS's `attach(to:)`, for a controller
  that attaches after the item already exists). macOS has no `externalMetadata` API, so the
  window title bar carries the name there instead (see `PlayerView`'s `.navigationTitle`).
- One app-scoped `PlaybackSession` / `PlayerManager` — do not allocate a new manager per route.
- Off tvOS: present (don't push) the player; macOS uses its own 16:9 window; iOS lets the system
  controller go full-screen for Done. Every play entry point goes through `PlayerLink` — a
  `NavigationLink` to the player route puts the film in the macOS detail column with the sidebar still
  visible, which is a bug (see [07](../features/07-playback-conveniences.md)).
- The player draws no chrome of ours: no custom title, no Cancel button, no centre panel. Exit is the
  window close button, Done, or Menu.
- Subtitles: system HLS renditions off tvOS; tvOS may use sidecar overlay for dual tracks. Hide the
  duplicate system subtitle button when our menu owns sidecar/dual.
- Audio: prefer system picker + master `NAME=` relabel via `HLSAudioLabeler`; remember per-show picks
  when implemented.
- Stream survey: current kino.pub deliveries surveyed were AVFoundation-friendly H.264/AAC —
  **no FFmpeg engine** for core playback. Capability **badges** may still show 4K/HDR when item flags
  say so (device/profile dependent); do not globally ban badges from one survey.
- Player rewrite is **out of scope** for early stages; skips / Up Next are thin conveniences later.

## Needs validation

- Real Siri Remote: Menu dismiss, Subtitles menu, Up-swipe trailer fullscreen, dual-sub focus.
- Whether AVKit audio picker shows relabeled metadata titles vs language-only `displayName`.
- Deduplicating triple AUDIO groups in HLS masters without breaking ABR.
- Whether `AVPlayerView`'s public `controlsStyle` values (`.default` / `.floating` / `.minimal` /
  `.inline`) can actually reproduce what TV.app / Music.app show on macOS, or whether those apps
  draw chrome outside `AVPlayerView`'s documented surface. Not investigated — see
  [07-playback-conveniences.md](../features/07-playback-conveniences.md), "macOS AVKit chrome is
  the public surface." Needs a real screenshot-by-screenshot comparison, not a guess.
