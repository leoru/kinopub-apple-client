# 05 — Player and media

Condensed English summary of a 2026-07-25 research pass on `AVPlayerViewController` customization,
what the current player implementation gets wrong, and what to borrow from the reference apps.
Availability was checked against Xcode 27 / `AppleTVOS27.0.sdk` headers and `swiftc -typecheck`, not
documentation alone — Apple's web docs were found to be wrong in places (see Pitfalls). Current
guidance and the correctness bugs this report found now live in
[`.claude/skills/tvos-surface/SKILL.md`](../../../.claude/skills/player-avkit/SKILL.md) and
[`ROADMAP.md`](../../../ROADMAP.md)
(resume race, wrong-episode resume, Skip Intro, subtitle encoding/validation, cue-lookup
performance, player perf items — all carried forward from this report's §3/§4 almost verbatim).
Russian original: `05-player-media.ru.md` (gitignored, local only).

## TL;DR (at the time)

- **On-device English auto-subtitles: yes, but tvOS 27 only.** The `Speech` framework isn't in the
  tvOS 26 SDK at all (a documented known issue). tvOS 27 has it, and — critically — ships
  `AVPlayerItemSampleBufferOutput`, which delivers **decoded PCM straight from an HLS player item**
  ("currently supported for HLS `AVPlayerItems` only"). Before 27 this was flatly impossible:
  `MTAudioProcessingTap` doesn't work with HLS. The whole pipeline type-checked end to end. Caveat:
  it transcribes whichever audio track is *selected* — kino.pub defaults to Russian dubs, so
  "auto-English" only helps on titles with an original English track actually chosen.
- **tvOS downloads won't look like iOS downloads, and it isn't an API problem.**
  `AVAssetDownloadURLSession` is tvOS-unavailable, but the app doesn't use it anyway — the existing
  `DownloadManager` is a plain background `URLSessionDownloadTask` against progressive MP4. The real
  blocker is tvOS's file-system policy: only `Library/Caches` is reliably writable, and the system
  purges it whenever the app isn't running. Only "cache for this session" + next-episode prefetch is
  honestly shippable — not "offline library."
- **Skip Intro is a cheap, native fit.** `AVPlayerViewController.contextualActions` (tvOS 15+) is
  Apple's own "Skip" pill; `AVPlayerItem.navigationMarkerGroups` (tvOS 9+) gives a native "Chapters"
  panel. v1 data source: the gap between subtitle cues in the first ~8 minutes of an already-fetched
  SRT — no new backend service needed.
- **The custom subtitle overlay can't be deleted, but it's wired wrong today.** There is no public
  way to attach an external SRT to an HLS player item
  (`externalSubtitleOptionLanguages` is deprecated at birth and `NS_SWIFT_UNAVAILABLE`), and the
  system renderer can't do dual subtitles at all. But the app's overlay ignores Settings →
  Accessibility → Captions entirely, lives as a SwiftUI *sibling* of `AVPlayerViewController` rather
  than inside it, and goes dark on pause on tvOS. Fix: `MediaAccessibility` +
  `customOverlayViewController` + `unobscuredContentGuide`.
- **4K/HDR/DV/Atmos badges can't be honestly computed today — don't fake them.** Reliably derivable:
  quality tier, AC3/channel count *of the source* (not necessarily what HLS delivers), CC/SDH/Forced
  (filename heuristics only), audio description. HDR/DV live in `VIDEO-RANGE` /
  `SUPPLEMENTAL-CODECS` on the master playlist, and the app's manifest parser doesn't read either;
  Atmos has no signal in the kino.pub API at all.
- **A trap already live in the codebase:** tvOS 27's SDK ships `Translation` and `FoundationModels`
  modules, but their core types are `@available(tvOS, unavailable)`. That means
  `#if canImport(Translation)` now evaluates **true on tvOS** — the `&& !os(tvOS)` in
  `SubtitleTranslatePanel.swift`'s guard became load-bearing, not decorative. Don't simplify it away.

## What was available (SDK-verified)

`AVPlayerViewController` customization at tvOS 15+: `contextualActions`, `infoViewActions`,
`customInfoViewControllers`, `transportBarIncludesTitleView`; at tvOS 13+:
`customOverlayViewController`, `unobscuredContentGuide` (the region not covered by controls — meant
for exactly the subtitle-positioning problem above); at tvOS 16+: `speeds`/`selectedSpeed`; at tvOS
14+: `allowsPictureInPicturePlayback`. None of these are available on iOS/macOS
(`API_UNAVAILABLE(ios)`) — they're tvOS's answer to "customize without hand-rolling a transport bar."

Chapters/interstitials: `AVPlayerItem.navigationMarkerGroups` (tvOS 9+, **system reads only the
first group in the array**); `AVInterstitialTimeRange` (tvOS 9+) permanently collapses a range out
of the timeline and subtracts it from shown duration — right for a "previously on" recap, wrong for
an intro users sometimes want to watch; `AVPlayerInterstitialEvent` is for content *substitution*
(ads/bumpers), not skip — a real misreading risk this report flags explicitly.

Speech/translation (tvOS 26 → 27 delta, all compiler-verified): `Speech.framework` absent from the
tvOS 26 SDK, present in 27; `SpeechAnalyzer`/`SpeechTranscriber` compile at `anyAppleOS 26`;
`AVPlayerItemSampleBufferOutput` is **27.0-only** and is what makes the HLS→PCM bridge possible;
`Translation.TranslationSession` and `FoundationModels.SystemLanguageModel` are
`@available(tvOS, unavailable)` in both 26 and 27 SDKs, despite the frameworks existing on-disk.

Downloads: `AVAssetDownloadURLSession`/`AVAssetDownloadTask` — `API_UNAVAILABLE(tvos)`
(compiler-confirmed); plain `URLSessionDownloadTask` with a background configuration — available and
already what the app uses.

Other useful tvOS-available API not yet adopted at the time: `MediaAccessibility` (system caption
style — color, opacity, background/window, font, edge style, plus a change notification);
`AVPictureInPictureController`; `AVMetricEvent`/`AVMetrics` (26.0, native player telemetry — stalls,
bitrate switches — a candidate replacement for hand-rolled logging). `updatesNowPlayingInfoCenter`
is tvOS-unavailable **on purpose**: AVKit publishes Now Playing itself from `externalMetadata` — the
app doesn't need (and shouldn't add) its own `MPNowPlayingInfoCenter` code.

## What this became in the app

The correctness bugs cataloged in this report's §3 (resume race between `.onAppear`/`.task`, resume
reading the first episode instead of the current one via `.first` lookups, `Task.detached` with
`[unowned self]` outliving the manager, a second periodic time observer running redundantly,
`currentPlaybackTime` republished 4×/second, linear subtitle-cue scans, SRT encoding assumed
UTF-8/Latin-1 with no Windows-1251 fallback, `HLSAudioLabeler`'s leaked temp `.m3u8`,
`BestVideoQualityFinder`'s deprecated `UIScreen.main.bounds`) are now tracked as open items in
[`07-playback-conveniences.md`](../../../ROADMAP.md) and
[`01-foundation-continuity.md`](../../../ROADMAP.md) — check those for
current status rather than treating this archive as up to date on what's fixed.

## What was borrowed

**Rivulet**: a working `MediaAccessibility` → SwiftUI port (`CaptionAppearance.swift`) — reads
system caption color/opacity/background-or-window/font/edge-style and reacts to the system change
notification; two non-obvious traps documented there: the `behavior` out-parameter from
`CopyForegroundColor` gets overwritten by each subsequent call (read it immediately), and several
system caption presets express "background" as a *window* rather than character background, needing
an explicit fallback. Also: a `navigationMarkerGroups` builder with a chapter/intro/credits
fallback path, and the concrete "Skip" pill's constraint that `UIButton` on tvOS does **not** send
`.primaryActionTriggered` on Siri Remote Select — must be handled in `pressesBegan`. Not borrowed:
their fully hand-rolled transport bar and FFmpeg engine — both explicitly against this app's
native-chrome rule, and unjustified given the catalog is 100% `avc1`/`mp4a`/SDR/≤1080p per its own
stream survey.

**silo-apple**: the only *public* way to construct `AVDisplayCriteria` is via
`AVAsset.load(.preferredDisplayCriteria)` — Rivulet builds a throwaway `AVURLAsset` just to read it
back; silo's `AVDisplayCriteria(refreshRate:formatDescription:)` (tvOS 17+, public) is the
shippable alternative to a private initializer some code out there relies on. Also: waiting out an
HDMI mode-switch by polling `isDisplayModeSwitchInProgress` with a budget rather than trusting it to
flip immediately, a disk-space budget for cache/downloads, and documented Siri Remote behavior in
the player (Menu priority order, `focusSection()` around the transport cluster, a full-screen
invisible focus sink when chrome is hidden) that this app's player does not currently implement at
all.

## tvOS pitfalls from this report

A module existing in the SDK doesn't mean the API is available — `canImport` is not a availability
check for `Translation`/`FoundationModels` on tvOS. Apple's own web docs and SDK headers disagreed
in at least one place (`preferredDisplayDynamicRange`) — trust the SDK. Only the first
`navigationMarkerGroups` array element is read by the system. `UIMenu`/`contextualActions` arrays
are immutable — rebuild only on actual state change, not every tick. `UIScreen.main` reports UI
points (1920×1080) even on a 4K Apple TV. `MTAudioProcessingTap` never worked with HLS — there was
no access to decoded player audio before `AVPlayerItemSampleBufferOutput`. HDMI mode switching
blanks the screen for several seconds; `AVDisplayManagerModeSwitchStart/EndNotification` exist so UI
can ride through it. VoiceOver needs no extra code for the system player, but a custom subtitle
overlay must be `.accessibilityHidden(true)` or VoiceOver will read captions over dialogue.

## Open questions this report left unverified

Whether `Speech.framework` actually exists at runtime on tvOS 26.x hardware (SDK annotation and
tvOS 26 release notes disagree — treat as 27-only until proven otherwise); whether
`allowedSubtitleOptionLanguages = []` removes the subtitle button entirely or just leaves it with
only "Off"; how `contextualActions` actually renders and takes focus on a real remote relative to
the transport bar; the precise cost/backpressure behavior of `AVPlayerItemSampleBufferOutput` against
real kino.pub HLS; whether any kino.pub catalog item actually has a selectable original-English
track (which determines whether the whole auto-subtitle feature is worth building); and whether
`AVInterstitialTimeRange` really makes seeking skip over a recap range the way its header promises.
Any of these should be device-verified before being treated as settled.
