# 02 — Access and app shell

**Status:** In progress  
**Goal:** Reliable device-code / QR activation and authorization, plus Settings as a real sidebar
destination with working grouped sections.

## Accepted behavior

- Full-screen activation modelled on system AirPlay-code: material background, per-character tiles,
  silent refresh of expired codes, no dismiss chrome that fights the flow.
- Tokens in Keychain; unauthorized state shows activation, not a broken shell.
- Settings lives in the adaptive sidebar / tab shell and actually configures the app.
- macOS may also expose Settings via the application menu / settings scene when appropriate.

## Settings taxonomy (draft groups)

Use native `Form` / `List` sections. Hide platform-inappropriate groups (e.g. Downloads on tvOS).

- General
- Playback
- Integrations (Kinopoisk key, TMDB proxy notes, future sources)
- Downloads (non-TV; feature-gate until ready)
- Devices (kino.pub device profile / HEVC–4K–HDR flags)
- Appearance / Design (dark-only until stage 05 light theme)
- Sidebar (macOS customization; Finder-like where system allows)
- Notifications
- Content / Metadata (which enrichment sections to show)
- Sync & Backup (aspirational — after local DB foundation)
- Network / Diagnostics (stream survey lives here today)
- Advanced
- About / Changelog

## Checklist

- [x] Device-code authorization + Keychain tokens + activation UI baseline
- [ ] QR / copy-code polish and reliability (activation note + error recovery)
- [ ] Settings as first-class sidebar destination with the groups above (start with General,
      Playback, Integrations, Diagnostics, About)
- [ ] Feature-gate incomplete settings panes rather than empty dead ends
- [ ] Auth changes must not wipe Kinopoisk keychain service (already separate — keep it that way)

## Validation

- [ ] Cold launch → activation → authorized shell on tvOS and macOS
- [ ] Settings focusable from sidebar; sections scroll and persist values
