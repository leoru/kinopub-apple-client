# Research plan: baseline-26 move and UI/player upgrade

Condensed English summary. Dated 2026-07-25. Owner confirmed raising the deployment floor to
**26.0 on every platform** (27-only marked separately). Russian original: `00-plan.ru.md` (gitignored,
local only).

## Starting point

| | kinopub-apple-client | Rivulet | silo-apple |
| --- | --- | --- | --- |
| Deployment targets | tvOS 17 / iOS 16 / macOS 15 | tvOS 26.0–26.2 | 26.0 |
| Liquid Glass calls | 0 | 3 files | 6 files + `DesignSystem/SiloGlass.swift` |
| Swift | 5.9 | 6.0 | — |
| `.swift` files | 223 | 317 | 548 |

Our stack: one multiplatform target + 4 local packages (`KinoPubUI`, `KinoPubKit`, `KinoPubBackend`,
`KinoPubLogging`). Navigation was `TabView` + `.sidebarAdaptable` behind
`if #available(iOS 18, tvOS 18, macOS 15)` branches.

## Pain points driving the pass

From README "Known issues" plus a code scan:

1. **Focus.** The preview hero (`MediaRowsView(showsFeaturedPreview:)`) was disabled everywhere — a
   hand-rolled Metal progressive blur repainted on every focus move and drew over the tab bar.
   Default focus on detail and in the player was unverified on a real remote.
2. **Fixed-size layout.** ~60 hardcoded frames, worst in `MediaCardView.swift` (11),
   `SeasonsRailView.swift` (9), `MediaItemDetailSections.swift` (6). No grids / `ViewThatFits` /
   `containerRelativeFrame`.
3. **Tabs were a mess.** 630 lines in `TabsNavigationView.swift` with manual per-platform branches, a
   legacy fallback, and folder snapshots; no system counters/badges, no customization outside macOS.
4. **No Liquid Glass at all** — any "glass" look was either absent or hand-rolled.
5. **Player** — `AVPlayerViewController` used directly, but chapters, interstitials, skip intro,
   auto-subs, HDR badges were untouched; no Downloads on tvOS.
6. **Images** — a custom `AsyncImage` path, no native cache, no layered/parallax previews.
7. **No atoms** — titles/labels/badges rebuilt per screen; Dynamic Type and accessibility sizing
   unverified.

## Research categories

Nine tracks. Each agent: read our code → fetch Apple docs → study both reference apps → write a
report with concrete files and patches.

| # | Report | Covers |
| --- | --- | --- |
| 01 | `01-layout.md` | Grid/GridRow/LazyHGrid, ViewThatFits, containerRelativeFrame, alignment guides, lockups, moving off fixed frames |
| 02 | `02-liquid-glass.md` | `glassEffect`, `GlassEffectContainer`, morphing, scroll edge effect, materials, `MaterialActiveAppearance`, replacing the Metal blur |
| 03 | `03-navigation-tabs-search.md` | `Tab`/`TabSection`/`.search` role, `tabBarMinimizeBehavior`, `TabViewCustomization`, badge counters, floating search, suggestions, NavigationStack/SplitView |
| 04 | `04-cross-platform.md` | One codebase across 4 platforms: scenes, multiwindow, menu bar/`CommandGroup`, size classes, what degrades where |
| 05 | `05-player-media.md` | AVKit customization on tvOS, navigation markers/chapters, auto-subtitles, HDR, PiP/AirPlay, HLS downloads on tvOS, skip intro |
| 06 | `06-tvos-focus.md` | Focus engine, focus sections, `defaultFocus`, TVUIKit, layered images/parallax, tvOS 26/27 release notes, Top Shelf |
| 07 | `07-ui-components-a11y.md` | Atomic components: badges (4K/CC/SDH/HDR), masked marquee text, avatar placeholders, Dynamic Type, VoiceOver, image cache |
| 08 | `08-performance.md` | `@Observable`/automatic observation tracking, blur cost, lazy stacks, image decoding, Apple TV memory, Instruments |
| 09 | `09-metadata-integrations.md` | Trakt + TMDB (+ Kinopoisk Unofficial): what each gives, how to match, what to surface |

## Rules given to the research agents

- **Read-only on the codebase.** Nothing changed except the agent's own report file.
- **Verify everything by fetching.** Model knowledge may not cover 26–27 / WWDC 2026; anything
  unconfirmed gets marked "UNVERIFIED".
- **Be concrete.** Reference our files as `path/File.swift:123`, sketch actual Swift.
- **Prioritize.** Quick wins (hours) / medium (days) / architectural (weeks).

## Report structure

1. TL;DR — 5–10 bullets
2. What's available at baseline 26 (27-only called out separately) — API / platform / benefit / link
3. Where we stand today — files:lines, what's wrong
4. Recommendations — quick wins / medium / architectural
5. What to borrow from Rivulet and silo-apple — files:lines
6. tvOS specifics and pitfalls
7. Open questions / unverified
8. Sources

## After the research pass

Roll the nine reports into one migration plan: phase order, what breaks when the deployment target
moves, what gets rewritten into `KinoPubUI` as an atom library, and update `README.md` + `AGENTS.md`.

**What actually happened:** superseded by [`modernization.md`](../plans/modernization.md), now closed
to pure history — live work moved into [`docs/en/features/`](../../../ROADMAP.md). Current guidance
lives in [`docs/en/apple-platform/`](../../../.claude/skills/).
