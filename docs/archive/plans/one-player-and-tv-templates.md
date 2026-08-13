# Plan: one player, and the tvOS template study

> **Archived 2026-08-13.** Survived: one `AVPlayer` at a time (AGENTS.md, `player-avkit` skill),
> and its own opening warning — a reference app shows *that* something is possible, never *how*;
> find Apple's documentation for the API before building from it. The template study fed the
> three-cells-one-collection standard in the `tvos-surface` skill.


> **Dated plan — not living authority.** Started 2026-08-10, carried over from a
> session that ran out of room before implementing any of it. Durable rules it feeds:
> [component-catalogue](../../../AGENTS.md),
> [apple-native-design](../../../AGENTS.md).
>
> **Read this before writing code from it.** Everything below was arrived at by
> reading two other apps and one Apple guide. Reference apps show *that* something is
> possible and roughly how; they are not the specification. Before implementing any
> item here, find Apple's own documentation for the API involved and build to that.
> This session was a long lesson in the cost of skipping that step: we hand-rolled
> four things (`onScrollVisibilityChange`, a custom `ScrollTargetBehavior`, the
> material gradient mask, `.focusSection()` on a full-width header) that Apple's tvOS
> layout guide spells out, and burned days on symptoms each of them would have
> prevented.

## Licensing

Reference apps (Rivulet, Plozz) are read for **technique only** — never copied code.
Same rule as [community-fork](../../community-fork.md). Paths cited below are evidence
for *why* a decision is what it is, not files we vendor.

---

## 1. One player — the actual business rule

**Rule:** the app has exactly one video player at a time. Not "one `PlaybackSession`"
— one `AVPlayer`. This is already a project decision; what is missing is the
architecture that makes it true.

### What is wrong now

`TrailerPreviewModel` is a `@StateObject` **inside** `MediaItemView`. Every detail
page constructs its own `AVPlayer`. Navigating through titles (observed live:
124966 → 124447 → 125644 → 124795 → 125839 → 124600) leaves a trail of them, because
`stop()` hangs off `onDisappear`, which a covered page in a `NavigationStack` does not
reliably get.

Ownership is inverted: the page owns the player. It should own only a *layer*.

### The technique to aim at

From Plozz's `Sources/HeroUI/HomeHeroBackdrop.swift`. The hero takes the controller as
a **parameter** (`var trailerController: HeroTrailerController?`), never creates one,
and renders two video layers over the same controller:

- one layer per role (`.home`, `.detail`);
- the destination layer is mounted *before* the push at `opacity(0.001)` — not hidden.
  Their comment says why: hidden layers do not stay in the render tree and have no
  frame ready, so the handoff would stutter;
- the transition is therefore a **cross-fade between two layers of one player**, not a
  new player. Same frame, same audio, same subtitle selection, because nothing about
  the player changed;
- `scrimOpacity`: the outgoing screen gives up its scrim during the push so two dark
  overlays never stack.

One `AVPlayer` can back many `AVPlayerLayer`s. Layers are cheap; players are not.

### Steps

- [ ] Move `TrailerPreviewModel` ownership up to the router / app shell. Pages receive
      it as a parameter, exactly as `MediaItemHeroPhase` is passed today.
- [ ] Introduce a role-tagged video layer view; mount the destination role ahead of the
      push at ~0 opacity.
- [ ] Hand off by cross-fading layers; never stop/start the player across a push.
- [ ] The receiving screen owns the scrim during handoff.
- [ ] **Verify against Apple's docs first:** `AVPlayerLayer` sharing semantics, and
      whether `AVPlayerVideoOutput` / the tvOS-recommended path supersedes attaching
      multiple layers. Do not implement straight from the Plozz shape.
- [ ] Confirm with Instruments **Allocations**, filtered on `AVPlayer` /
      `AVPlayerItem` / `AVPlayerLayer`: walk six detail pages, the live count must not
      grow. (The Logging instrument used this session shows `os_log` only and cannot
      answer this.)
- [ ] Temporary fallback if the above slips: disable the ambient trailer on the detail
      page entirely. kino.pub never had it; a missing nicety beats a player leak.

### Open question, unresolved

The user recalls Apple documentation describing how to continue a playing tvOS
preview into a full-screen player one layer up — same position, with sound, keeping
the subtitle selection. Find it before designing the expand transition; it likely
names the supported mechanism and makes the two-layer trick unnecessary.

---

## 2. tvOS templates — TVML / TVUIKit study

TVML is deprecated as a *transport* (XML + a JS engine). Its `productTemplate` remains
the clearest published specification of what an Apple TV media page **is**, and every
Apple TV app still looks like it. Treat it as the spec; build from native parts.

The component list is already codified in
[component-catalogue](../../../AGENTS.md) — that policy is the durable
output of this study and should be extended, not duplicated.

- [ ] Read the TVML element reference **specifically for video**: the user's read is
      that there are facts there about playback surfaces the reference apps did not
      pick up. Not examined this session; do not assume it is covered.
- [ ] Cross-check each element against a current native equivalent (TVUIKit first) and
      extend the catalogue table.
- [ ] Elements with no native equivalent — `ratingCard`, `reviewCard`, `ratingBadge` —
      are ours to own, in one place each.

---

## 3. Badges are artwork, not text

The asset catalogue already carries them (HDR, Dolby, content rating, checkmark,
brand marks — added by the user). The legend built this session renders text labels
instead, which the user rejected: on a footer strip, wordmarks read wrong.

- [ ] Replace text badges with `Image`s from the asset catalogue.
- [ ] Keep the *decoding* idea — Apple spells CC and AD out in prose under
      Accessibility, and a legend nobody explains is decoration. Icon in the strip,
      sentence in the legend.
- [ ] Only claim what the payload supports: kino.pub carries no HDR / Dolby Vision
      flag, so those badges must not be inferred.

---

## 4. About block — still unsettled

Four candidate compositions are live behind a DEBUG switch at the top of the About
block (`MediaItemAboutLayout`): Apple shape / decoded legend / tiles + table / spec
sheet. Not yet judged on device — the switch was unreachable on the build the user
was testing.

Standing constraints from the user, which the four variants only partly honour:

- The table **stays a table**: bottom of the page, quiet, flat background that says
  "skip unless you need this", free to grow as metadata multiplies. Splitting it into
  separate card blocks was rejected.
- What you decide *before pressing play* — quality, resolution, colour, dub, subs,
  and sometimes the parental rating — is not table material. It wants the weight of
  the ratings row: card-backed, because the background is the affordance.
- Parental rating may deserve its own card when there is a "why" (a parental guide
  breakdown) or when the code is opaque (`TV-MA`).
- Languages: the viewer's own languages in system preference order, best dub in each,
  falling back to English then the original. Implemented; unverified.
- Big section headings take attention the content wants. Shrink them.
- Facts / photos / reviews / where-to-watch / release cadence exist in the data and are
  currently hidden — bring them back as small blocks, not as new headings.

- [ ] Judge the four on device, keep one, delete the rest **and the switch**.

---

## 5. Networking — no library needed

Fixed this session: `GET /v1/bookmarks` fired 25+ times on launch because 16 files
each own a `MediaCardMenuCoordinator` and each called `refreshFolders()` on `.task`.
A shared single-flight + TTL cache now sits behind that method; no call site changed.

Remaining, and visible in the same log:

- [ ] **Device-token polling has no interval.** ~20 `POST /oauth2/device` in a row,
      each returning 400, back to back. The device flow expects a wait between polls
      (typically 5s, and the server may return an `interval`). One `Task.sleep` at the
      poll site.
- [ ] Consider generalising the single-flight cache to all idempotent GETs rather than
      one method.

**Alamofire: no.** It brings interceptors and retriers but no request de-duplication,
which was the actual defect; that was solved in ~50 lines on `URLSession`. The
`curl`-line request logging we already emit is better than most.

**Swift 6 language mode: not now.** The project builds `-swift-version 5`. Strict
concurrency addresses data races, and none of the symptoms driving this work
(duplicate requests, stranded focus, scroll landing) are data races. `@Observable`,
structured concurrency and task cancellation are all already available here and in
use. Raise the language mode as its own pass once the UI settles.

---

## 6. Focus diagnostics — keep

A DEBUG global tracer is installed (`FocusLog.startGlobalTrace`, on
`UIFocusSystem.didUpdateNotification`) plus a whole-window stranded-cell sweep. It
exists because per-view instrumentation had blind spots by construction:
`@Environment(\.isFocused)` is only true *inside* the focused view's subtree, so any
reporter attached outside a `Button` never fired.

- [ ] SwiftUI focus items are private responder types, not `UIView`s; the tracer digs
      the backing view out by reflection. If Apple renames those internals it degrades
      to a type name — acceptable for diagnostics, but do not build behaviour on it.
- [ ] Stranded-scale detection is confirmed real but small (1–2 cells). The user
      reports ~15 lit at once, which the scale check does not explain — the remaining
      suspect is `TVPosterView`'s own highlight rather than a transform. Needs the
      screen-wide sweep read on device before any fix.
- [ ] Root cause of the stranding class is architectural: each shelf is a separate
      `UICollectionView`, so moving between rows *leaves the collection* every time —
      the exact case Rivulet's own comment calls unreliable, and for them a rare edge
      case. One collection for the below-fold is the structural fix.

---

## Order

1. Player ownership (§1) — the only item with a correctness and memory cost.
2. Device-token interval (§5) — one line.
3. Judge the About variants (§4) — needs the user, not code.
4. Badges from assets (§3).
5. TVML video study (§2) → extend the catalogue.
6. Below-fold single collection (§6) — the largest, and it subsumes several bugs.
