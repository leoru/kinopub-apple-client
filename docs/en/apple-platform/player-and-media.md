# Player and media

## Evergreen

- Prefer `AVPlayerViewController` system chrome on every platform. Custom transport bars fight AirPlay,
  Now Playing, and accessibility.
- tvOS customization points: `transportBarCustomMenuItems`, delegate dismiss, interstitial /
  navigation markers where applicable.
- `AVAssetDownloadURLSession` offline model does **not** give tvOS the same downloads UX as iOS —
  Downloads stay non-TV.
- Auto / live transcription pipelines that need decoded PCM from HLS are largely **tvOS 27+**
  concerns (`Speech` / sample-buffer paths). Treat advanced subtitle intelligence as a late stage.
- Skip intro databases (TheIntroDB, AniSkip) key off IMDb / TMDB / MAL — useful after catalog IDs are
  solid; see feature doc for playback conveniences.

## Project decisions

- One app-scoped `PlaybackSession` / `PlayerManager` — do not allocate a new manager per route.
- Off tvOS: present (don't push) the player; macOS uses its own 16:9 window; iOS lets the system
  controller go full-screen for Done.
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
