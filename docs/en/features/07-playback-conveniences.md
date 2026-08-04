# 07 — Playback conveniences

**Status:** Not started (some memory pieces exist)  
**Goal:** Playback memory, skip intro/recap/credits, and Up Next — **without** rewriting the native
player.

## Accepted behavior

- Native `AVPlayerViewController` remains the chrome.
- Remember audio (and already: subtitle) picks per show when possible.
- Skip / Up Next are thin overlays or system interstitial integrations when available.
- End-of-playback policy (auto next season vs stop) needs an explicit Settings decision before coding.

## Checklist

- [x] Per-show subtitle track memory (`SubtitleTrackReference`)
- [x] Dual subtitles option (tvOS) — parked defaults OK
- [ ] Per-show audio track memory
- [ ] Fix subtitles-follow-episode bug (`MediaItem.subtitles` reads first video only)
- [ ] Skip control — subtitle-gap heuristic first
- [ ] TheIntroDB (IMDb/TMDB keys) cached per episode
- [ ] AniSkip for anime once MAL/AniList match exists
- [ ] Up Next / end-of-playback behavior + Settings
- [ ] Resume prompt default documented (blocking vs always-continue)

### Correctness bugs (moved from the modernization plan)

- [ ] **Resume race:** `PlayerView` `.onAppear` → `fetchWatchMark` → seek
- [ ] **Resume reads the wrong episode** in `PlayerManager`
- [ ] **Skip Intro natively:** `AVPlayerViewController.contextualActions` (tvOS 15+) is Apple's own
  affordance — use it before any custom overlay
- [ ] Subtitle overlay hardcodes styling instead of respecting the system caption settings
- [ ] SRT fetch needs encoding detection + validation (Russian subs are routinely windows-1251)
- [ ] Cue lookup: binary search + cursor instead of a linear scan over ~2000 cues several times a
  second

### Player performance and lifetime

- [ ] Drop the second periodic observer; stop republishing `currentPlaybackTime` four times a second
- [ ] `PlayerTimeObserver` fires its callback on `.global(qos: .userInteractive)`
- [ ] `Task.detached(priority: .utility) { [unowned self] … }` in `PlayerManager`
- [ ] `HLSAudioLabeler` writes a temp `.m3u8` per launch into `tmp/kinopub-hls` and never cleans up
- [ ] `BestVideoQualityFinder` uses deprecated `UIScreen.main.bounds`, which reports 1920×1080pt even
  on 4K Apple TVs

Detailed rationale and file:line references stay in
[`modernization.md`](../plans/modernization.md).

## Out of scope

Full custom player, FFmpeg engine, language-learning tap-a-word (stage 08).
