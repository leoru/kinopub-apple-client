# 06 — tvOS focus engine, TVUIKit, layered images

Condensed English summary of a 2026-07-25 research pass, baseline tvOS 26 (27-only noted
separately). Current guidance lives in
[`.claude/skills/tvos-surface/SKILL.md`](../../../.claude/skills/tvos-surface/SKILL.md), including
the TVUIKit inventory table added this session. This report's diagnosis of the app's focus
architecture at the time is the direct ancestor of that policy's "one focus owner per zone" rule and
the ban on `.buttonStyle(.plain)`. Russian original: `06-tvos-focus.ru.md` (gitignored, local only).

## TL;DR (at the time)

- **True Apple-style parallax (layers sliding against each other) is impossible for us.** HIG is
  explicit: "Layered images are **required** to support the parallax effect." A flat image gets
  lift + scale + specular highlight + tilt-toward-remote (rendered as Liquid Glass on tvOS 26) but
  never inter-layer shift. Two much cheaper wins exist instead — see below.
- **The app likely wasn't getting the system focus effect on cards at all.** `.buttonStyle(.borderless)`
  attaches its `highlight` hover effect to "the first `Image` within the button's label" — and the
  label held an `AsyncImage`, not an `Image`. One explicit `.hoverEffect(.highlight)` line fixes it.
- **The hero-preview slowness was a full-screen 24-sample shader on every focus move, not "focus
  being slow."** A `layerEffect`-based progressive blur recomputed every composited frame instead of
  being cached once per URL change into a small offscreen buffer.
- **`defaultFocus(..., priority: .userInitiated)` was a bug**, not a stylistic choice — the
  Apple docs define `.userInitiated` as "always use the default focus preference when focus moves
  into the affected branch," meaning every re-entry into a rail (from the tab bar, from search, from
  a detail push) threw focus back to the first card. The fix is `.automatic`.
- **Multiple focus owners on the same screen** — `defaultFocus` + a manual `.task { sleep(120ms);
  focusedCard = … }` + a `hasClaimedFocus` flag — is exactly the anti-pattern silo-apple's own focus
  doc calls "Do Not Mix Models."
- **`focusScope` was mistaken for `focusSection`.** `focusScope` only affects default-focus
  preferences and plays no part in directional movement — which is why an invisible 8pt
  "focusBridge" with programmatic focus-writing existed as a workaround. The correct tool is
  `.focusSection()` on the container.
- **Dead 560pt of inert space existed on-screen**, contradicting the app's own no-inert-space rule
  — a `Color.clear.frame(height: 560)` branch rendered on the very first frame of any hero-enabled
  screen, before a card had focus.
- **HIG safe-area insets were violated**: 80pt sides / 60pt top-bottom is the spec; the app used
  48pt and `.ignoresSafeArea(edges: [.top, .horizontal])` around content, not just artwork.
- **Posters were undersized** relative to both HIG's card-grid table and both reference apps —
  200×300 vs. Apple's own sample at 250×375 and Rivulet at 296×444 (whose "shelf equation" is worth
  taking wholesale, see below).
- **From TVUIKit, exactly one thing was worth adopting: `TVMonogramContentView`** (localized
  initials from `PersonNameComponents` for actor portraits) — `TVMonogramView` is deprecated,
  `TVPosterView`/`TVCardView` cost more than they give a SwiftUI app (Rivulet's own code documents
  the poster-focus-scale desync and overlay-placement fights that come with them).
- **tvOS 26/27 did not change any focus modifier.** What changed: Liquid Glass on focus effects, a
  real safe-area inset under `sidebarAdaptable`'s sidebar (this directly explains "content drew over
  the tab bar" — see below), `ControlSize` finally affecting custom tvOS views, `buttonSizing`,
  HTTP-cached `AsyncImage` (27-only), and 27 buttons no longer auto-tinting from the accent color.
- **Top Shelf was unbuilt and is roughly a day of work.** Both reference apps have working examples;
  the recommended shape for this app is a carousel written from an App Group cache the main app
  already populates (Continue Watching), not a network call from inside the extension.

## What was available (verified against Apple's docs)

Focus: `@FocusState`/`.focused`, `.focusable`, **`.focusSection()`** (directional-movement target —
the main tool against "Up falls through"), `.focusScope()` (default-focus preference scope
**only**), `.defaultFocus(_:_:priority:)` with `DefaultFocusEvaluationPriority`
(`.automatic` vs. the dangerous `.userInitiated`), `@Environment(\.resetFocus)`,
`@Environment(\.isFocused)` (nearest focusable **ancestor**), `.focusEffectDisabled`,
`.onMoveCommand` (catches only directions the engine itself couldn't resolve), `@FocusedValue`
(a candidate mechanism for hero-preview state). None of this is new in 26/27 — it's been available
since tvOS 14–18 and simply wasn't in use.

Hover effects (what actually draws "parallax" in SwiftUI on tvOS): `.hoverEffect(_:isEnabled:)`
(17+), `HoverEffect.highlight` (18+, "lift, specular highlight, gimbal motion"),
`.buttonStyle(.borderless)` (attaches `.highlight` automatically **to the first `Image` in the
label**), `.buttonStyle(.card)` (a more restrained platter effect for information-dense lockups).

Layered images / true parallax: HIG requires 2–5 distinct layers, mandatory for the app icon,
"strongly encouraged but optional" for other focusable images including Top Shelf. Runtime layered
images (`.lcr`) must be generated server-side (`layerutil`) and downloaded, never bundled — not
something a flat-JPEG catalog like kino.pub's can produce.

TVUIKit inventory and verdicts are now consolidated in
[`focus-and-tvui.md`](../../../.claude/skills/tvos-surface/SKILL.md) rather than
duplicated here.

tvOS 26 relevant changes: `sidebarAdaptable` content now gets a real safe-area inset under the
sidebar and *can* draw outside it underneath — the direct explanation for "content drew over the
tab bar," and the reason `.ignoresSafeArea()` there became a deliberate opt-in rather than
accidental bleed. `ControlSize` and `buttonSizing(.flexible)` finally do something for custom tvOS
views. `NavigationLink`s in lazy containers collapse to a single view per link when built against
the 26 SDK — a free performance win for card rails, at the cost of `ContainerValues` no longer
bubbling from the label. Known issue: **tvOS 26 design updates never reach 1st-generation Apple TV
4K or older** — don't build legibility that depends on Liquid Glass.

tvOS 27: `AsyncImage` gains automatic HTTP caching (directly relevant to the app's uncached image
pipeline, but 27-only); buttons stop auto-tinting from the accent color; `@State` becomes a macro
with narrow init-assignment caveats; several button-related modifiers reset to default inside a
sheet/popover.

## What this became in the app

Session-verifiable facts as of this pass: `Color.KinoPub.background` is now opaque
(`Color.black` on tvOS) rather than `.clear` — this report's §3 predates and is consistent with that
fix. The `.buttonStyle(.plain)` warning in this report (item 13 of the pitfalls checklist below) is
now a stated rule in `AGENTS.md`. The focus-ownership findings (`.userInitiated` misuse,
`focusScope`/`focusSection` confusion, `focusBridge` hacks, offset-driven "slideshow" focus) map
directly onto still-open items tracked in
[`01-foundation-continuity.md`](../../../ROADMAP.md) — check that doc, not
this archive, for current status. The hero/hoverEffect/parallax recommendations below fed the
now-**superseded** Netflix-style hero decision — see
[`focus-and-tvui.md`](../../../.claude/skills/tvos-surface/SKILL.md), which reopened that direction per
later product decisions; this report's `containerBackground(for: .tabView)` +
small-buffer-blur-instead-of-shader recipe is still the right technical approach if that hero gets
rebuilt.

## The focus-ownership model (still the core lesson)

silo-apple's own focus doc names exactly two allowed patterns: **Native Focus Graph** (stable
`Button`/`NavigationLink`s, grouping via `focusSection`/`focusScope`, `@FocusState` used only to
*seed* focus) or **Composite Focus Control** (one `.focusable(true)` container, passive row labels,
all D-pad handling through a single `onMoveCommand`). A hybrid of the two — reading focus state in
one place while also writing it programmatically in response to movement — is the third, disallowed
option, and was what this report found in the app's season-rail focus handling at the time.

Checklist worth keeping intact:

- **One decision-owner per zone.** `defaultFocus`, manual `@FocusState` writes, and
  `prefersDefaultFocus` should never coexist for the same region.
- **Never write focus in response to movement.** If that seems necessary, the focus model chosen for
  that control is wrong.
- **`.userInitiated` only for modals** — in an ordinary container it steals the user's position on
  every re-entry.
- **The focus engine searches in a straight line.** Anything not directly above/below/beside the
  cursor is unreachable without a full-width `.focusSection()` — never `.focusScope`, which does
  nothing for directional movement.
- **Move focusable content with layout** (`frame`, `padding`, alignment) — never `.offset` or
  `.rotation3DEffect` — because tvOS resolves focus from layout frames.
- **Nothing inert wider/taller than ~100pt on a movement path.** Reserved space must be focusable or
  absent, never a dead `Color.clear` block.
- **`.opacity(0)` does not remove something from focus** — pair it with `.allowsHitTesting(false)`
  or `.focusable(false)`.
- **Leave room for the focus lift** — `.scrollClipDisabled()` or sufficient padding, per HIG Lockups.
- **If you draw your own focus effect, disable the system one** (`.hoverEffectDisabled()` +
  `.focusEffectDisabled()`) — otherwise two competing scale animations fight.
- **The Simulator does not reliably reproduce tvOS focus-engine behavior** — Rivulet's own
  troubleshooting notes say to treat simulator-only verification as provisional; this matches
  `AGENTS.md`'s existing "Driving the remote" guidance.

## What was borrowed

**Rivulet**: `HeroBackdropImage`'s crossfade between two already-decoded `UIImage`s via local
`@State`, so only the backdrop redraws — not a shader on a `@FocusState`-derived value re-evaluating
the whole screen; a "settle" delay (`applyPendingUpgradeIfReady(minimumStableDuration: 0.15)`) that
defers upgrading to full-resolution art until focus has stopped moving for 150ms; the poster
"shelf equation" (`1920 = 2·rowLeading + N·tileWidth + (N-1)·gap`) as an invariant, expressible in
SwiftUI via `containerRelativeFrame(count:spacing:)`; a documented catalog of `TVPosterView`
integration problems (overlay placement fights, focus-scale desync, "poster strands enlarged") as
the concrete argument against adopting TVUIKit posters; a single shared focus-scroll easing constant
instead of four different durations scattered across files; `hoverEffectDisabled()` +
`focusEffectDisabled()` paired whenever a custom focus effect is drawn.

**silo-apple**: `docs/tvos-focus.md`'s two-pattern focus model above; the explicit rule that
`onMoveCommand` belongs only at intentional dead-ends, never intercepting normal in-zone movement;
a "Top Menu Ownership" state model (closed / preview / entered) as a template for a hero that shows
a focused card's preview without itself holding focus; a debugging checklist (log the focused
element, open panel, preview/entered mode, every handled `onMoveCommand`) worth carrying into
`AGENTS.md`; and — notably — a documented alternative hero shape: a **passive marquee** that is
never itself focusable, where rows own all focus and Up from the first row simply exits to the
sidebar. That avoids both the 560pt-of-dead-space problem and the "how does Up not fall through"
question this report otherwise solves with `focusSection()` on the hero — a genuinely cheaper
tradeoff worth weighing if the hero is rebuilt.

## Top Shelf, briefly

Five steps: a new App Extension target (`com.apple.tv-top-shelf` — a stated, deliberate exception to
the one-target rule, since Top Shelf cannot live in the app target), an App Group for a shared
container, the **app** writing a Continue Watching cache and the **extension** only reading it
(TVServices explicitly warns extensions have low memory limits and should not do heavy work),
`TVTopShelfCarouselContent` populated from that cache with `previewVideoURL` for focus-triggered
trailer playback, and `TVTopShelfContentProvider.topShelfContentDidChange()` called after each
Continue Watching update. Rivulet's `TopShelfCache.swift` (plain `UserDefaults(suiteName:)`, no
files) is the concrete template preferred over silo's network-call-from-extension approach, since
the data already exists in the main app.

## Multi-user profiles

kino.pub has one account per household — `TVUserManager`'s profile APIs (mostly deprecated anyway)
aren't needed. The one cheap, worthwhile step: the
`runs-as-current-user-with-user-independent-keychain` entitlement, which keeps the Keychain (kino.pub
token) shared across Apple TV users while making `UserDefaults` (subtitle prefs, selected tracks,
local watch history) per-profile. Left unverified: how this interacts with the app's
`KeychainAccess` wrapper.

## Open questions this report left unverified

Whether `.borderless`'s hover effect actually attaches to `AsyncImage` (high-confidence "no," per
Apple's own "first `Image`" wording — the direct motivation for the explicit `.hoverEffect` fix);
platform availability of `HoverEffectGroup`/`hoverEffectGroup(id:in:behavior:)` on tvOS; whether the
offset-and-clipped "slideshow" pattern in the old detail view could strand focus on an invisible
slide (theory says risk is real; needs on-device verification with Up/Down at the Play button);
whether `\.isFocused` is readable from inside a `ButtonStyle`'s `configuration.label` subtree (two
contradictory comments existed in the codebase at the time — Apple's docs favor "yes," which would
make one of the app's custom focus-state workarounds removable); which container wins when
`containerBackground(for: .tabView)` is nested inside a `NavigationStack` inside a `Tab`; and the
actual on-device cost of the blur shader this report blamed for hero jank — flagged as a job for
Instruments / report 08, not measured here.
