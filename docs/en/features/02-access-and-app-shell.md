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

### Activation screen — settled 2026-08-06

Decided against alternatives that were tried and rejected on screen; do not re-derive them.

- **No Copy button.** The whole code block is the copy target. Hover lightens **every tile at
  once** — the tile fill, never the glyphs (dimming the code is dimming the one thing the screen
  exists for). Click copies and confirms with the shared `HudToast`.
- **Activate copies, then opens.** Sending someone to the site without the code on their clipboard
  means a second trip back to this screen.
- **Activate is glass *and* prominent** (`.glassProminent` — `.borderedProminent` was tried and is
  the wrong material, plain `.glass` is not accented), focused on appear, `.defaultAction`, and
  **exactly as wide as the code block** (width computed from tile metrics, not eyeballed).
- **Nothing moves while a code loads.** Five empty tiles are drawn at final size from the first
  frame (kino.pub codes are five characters); characters arrive via `.blurReplace`. No spinner in
  the layout — a spinner that appears and disappears is what used to shove the page around on every
  code refresh.
- **Expiry is a small draining ring *plus* the remaining time in figures.** A ring alone reads as a
  spinner: it says something is running, not how long is left.
- **The verification URL shows on every platform**, not just tvOS. It is what tells the user where
  they are being sent, and the only route left if Activate opens the wrong browser.
- tvOS has no copy target and no Activate button — no pasteboard, no browser. Tiles, ring and URL
  only; the footer keeps a fixed-height spacer so the layout matches the other platforms.

### Session lifetime

- A refresh rejection is **not** the same event as the user signing out — `logout(userInitiated:)`.
  Only an explicit sign-out may clear shared state; the automatic path clears the Keychain and
  nothing else. kino.pub **rotates refresh tokens** (refreshing retires the token that was used),
  so a build presenting a slightly stale token gets a 400 while the session is alive under the new
  one. Treating that as "session over" is what sends everything back to the activation screen.
- Debug builds share one session file; see
  [agent-workflow](../policies/agent-workflow.md#shared-debug-session).

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
- [x] Copy-code, expiry countdown, non-moving loader, Activate affordance (see above)
- [ ] **QR code on tvOS** — the remote has no pasteboard and no browser, so the phone camera is the
      real path off that screen. Sits beside the tiles / URL without moving them, same as
      everything else on this screen. Not started.
- [ ] Activation error recovery (what the screen says when the code request itself keeps failing —
      today it silently retries with a growing backoff and shows nothing)
- [ ] Settings as first-class sidebar destination with the groups above (start with General,
      Playback, Integrations, Diagnostics, About)
- [ ] Feature-gate incomplete settings panes rather than empty dead ends
- [ ] Auth changes must not wipe Kinopoisk keychain service (already separate — keep it that way)

## Validation

- [ ] Cold launch → activation → authorized shell on tvOS and macOS
- [ ] Settings focusable from sidebar; sections scroll and persist values
- [ ] A code arriving, and a code being replaced on expiry, move **nothing** on the screen
- [ ] Rebuilding / switching platform does not ask for a new activation code
- [ ] Activation screen checked on screen, not only compiled — it is only reachable signed out,
      so it is the easiest screen in the app to ship broken
