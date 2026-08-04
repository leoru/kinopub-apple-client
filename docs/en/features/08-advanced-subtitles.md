# 08 — Advanced subtitles

**Status:** Parked / late  
**Goal:** Complex subtitle intelligence, translation, and language-learning — **only after** stages
01–07 make a usable daily client.

## Why last

This work is large, platform-version sensitive (some live transcription paths are tvOS 27+), and easy
for agents to derail. Catalog, shell, Library/History, theme, Top Shelf, and basic playback
conveniences deliver more daily value first.

## Parked today

- Tap-a-word translation on pause (`SubtitleTranslatePanel` builds but is not presented).
- Live AI / SpeechAnalyzer captions where APIs exist.
- Broader language-learning product surface.

## Checklist (do not start early)

- [ ] Un-park tap-a-word with real remote focus validation — the word chips in
  `SubtitleTranslatePanel` have no `@FocusState` and no focusable treatment, so the panel is
  unusable on a remote as written
- [ ] Default English non-CC policy remains configurable
- [ ] OpenSubtitles / external fallback when kino.pub has no tracks
- [ ] tvOS 27+ live caption experiments behind availability checks
- [ ] Learning-oriented UI (vocabulary, etc.) only with an explicit product brief

## Depends on

Stable player session, per-show track memory, and catalog IDs from earlier stages.
