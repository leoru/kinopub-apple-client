# 01 — Layout and adaptive structure

Condensed English summary of a 2026-07-25 research pass, baseline 26.0, read-only (no code changed
during research). Most recommendations below **landed** during the modernization pass — see
[`.claude/skills/tvos-surface/SKILL.md`](../../../.claude/skills/apple-chrome/SKILL.md)
for current guidance and [`docs/en/plans/modernization.md`](../plans/modernization.md) for what
shipped. Kept here for the reasoning and file:line evidence, which is now stale. Russian original:
`01-layout.ru.md` (gitignored, local only).

## TL;DR (at the time)

- Nothing in 26 or 27 changed how to build TV shelves — `Grid`/`GridRow`, `ViewThatFits`, `Layout`,
  `containerRelativeFrame`, `contentMargins`, `safeAreaPadding`, `scrollTargetBehavior` had all
  shipped by 16–17. The app used almost none of it. This was a code problem, not an SDK-version one.
- **WWDC26 session 221, "Prepare your tvOS apps for Dynamic Type," was the important one.** tvOS 27
  ships system Large Text, and Apple names exactly our failure modes as the cause of breakage:
  hard-coded font sizes, fixed width/height constraints, rigid layouts — i.e. `MediaCardView`.
  Apple's own recipe: `containerRelativeFrame(.horizontal, count: dynamicTypeSize.isAccessibilitySize
  ? 4 : 6, spacing: 40)` on the card inside a `LazyHStack`.
- HIG gives an exact tvOS card-grid table (80pt side inset, 60pt top/bottom, 40pt gutter, ≥100pt
  row spacing; width at 6 columns = 260pt via `w(N) = (1920 − 160 − 40·(N−1)) / N`). The app's
  `cardWidth = 200`, `horizontalInset = 48`, `cardSpacing = 36` all missed the grid; both reference
  apps (Rivulet, silo-apple) sit exactly on the 6-column HIG value.
- Page insets disagreed between screens (`MediaRowsView` 48pt vs `MediaItemLayout`/`SeasonsRailView`
  80pt) — a visible 32pt seam between Home's left edge and detail's.
- **`LazyVGrid` on tvOS has a ragged-last-row trap**: the focus engine resolves moves geometrically,
  and an incomplete row has no focusable target under most columns — the D-pad gets stuck.
  silo-apple avoids `LazyVGrid` entirely on tvOS for this reason (see below).
- `Grid`/`GridRow` were a good fit for exactly one place: `MediaItemInfoColumns` (key/value pairs) —
  not the catalog, which needs a lazy grid for paginated results.
- `WidthThresholdReader.swift` was dead code (no references beyond its own preview) — deleted.
- A real bug: `.frame(height:)` immediately after `.frame(minHeight:)` in `MediaActionButtonStyle`
  pinned button height so it could never grow for larger text — same shape in two other files.

## What was available at baseline 26 (verified against Apple's docs)

Already shipping (≤26): `Grid`/`GridRow`, `gridCellColumns`/`gridCellAnchor`/`gridColumnAlignment`,
`LazyVGrid`/`LazyHGrid`/`GridItem`, `ViewThatFits`, the `Layout` protocol + `AnyLayout`,
`containerRelativeFrame` (including the `count:span:spacing:` overload), `visualEffect`,
`contentMargins`, `safeAreaPadding`, `scrollTargetBehavior`/`scrollTargetLayout`,
`onGeometryChange`, `@ScaledMetric` (tvOS 14+), `BackgroundProminence`, `CardButtonStyle` (`.card`,
tvOS 14+, UIKit analogue `TVCardView`).

New at 26.0 (all platforms incl. tvOS): `backgroundExtensionEffect()`, `safeAreaBar`,
`ConcentricRectangle` + `containerShape`.

27-only (WWDC 2026, then in beta): **tvOS Large Text / Dynamic Type** (the one that mattered),
adaptive-toolbar APIs (not applicable, tvOS has no toolbars), `.reorderable()`, `.swipeActions`
outside `List`, `Tab(role: .prominent)`.

HIG "Lockups" (tvOS-only page): Cards / Caption Buttons / Monograms / Posters, all "expand and
contract together as the lockup gets focus." No point sizes given — "any size appropriate for
content." HIG "Layout" *does* give the grid table above, plus: "layouts don't automatically adapt to
the size of the screen... apps show the same interface on every display" (tvOS canvas is always
1920×1080pt) and the 60pt/80pt overscan insets.

**Continue Watching vs. poster shelves are one system**, not two: same column width, different
`aspectRatio` and `count` — no separate `landscapeWidth`/`landscapeHeight` constants needed.

## What shipped from this report

- `ShelfMetrics` (inset/gutter/columns from container width + Dynamic Type, no `#if os` per view) —
  landed in `KinoPubUI/Layout/`.
- Page insets unified to 80pt / 40pt gutter.
- `WidthThresholdReader.swift` deleted.
- The `.frame(height:)`-after-`.frame(minHeight:)` bug fixed.
- `@ScaledMetric` applied to square/hairline dimensions.
- `MediaItemInfoColumns` → `Grid`/`GridRow` — tracked as still-open in
  [`01-foundation-continuity.md`](../../../ROADMAP.md).

## tvOS pitfalls worth keeping in mind

- tvOS has one canvas (1920×1080pt at both 1080p and 4K) — hardcoded values "work" on TV and break
  on iPhone because TV never stress-tests them.
- Focus lift grows a card beyond its frame; without vertical padding + `.scrollClipDisabled()` the
  lift gets clipped.
- `Grid` is eager (renders all children immediately) — fine for a handful of info rows, wrong for a
  paginated catalog grid.
- `containerRelativeFrame` measures container minus safe area and does **not** see `contentMargins`
  — pair it with `safeAreaPadding`, not `contentMargins`, or column arithmetic drifts.
- `.system(size:)` fonts never scale with Dynamic Type — a strictly worse failure mode than simply
  not supporting it, since surrounding system chrome grows and the text does not.
- HIG confirms two things the app already did right: poster title/subtitle hidden until focus, and
  initials as the monogram fallback when a portrait is unavailable.

## What was borrowed

- **Rivulet** (`MediaRowMetrics.swift`): the *idea* that card width is an equation solved from
  screen width, column count, and gutter — not a constant. Their specific numbers (52pt margin, 8pt
  gap) were not used; `containerRelativeFrame(count:span:spacing:)` solves the same equation given
  HIG's 80/40. Also: a `CLAUDE.md` warning that Rivulet ported its main tvOS surfaces from SwiftUI to
  UIKit after measurable hitches from per-cell `UIHostingController` — a cost to plan for, not a
  recommendation to preempt.
- **silo-apple** (`TVCatalogGrid.swift`): explicit full-width focus-section rows instead of
  `LazyVGrid` on tvOS, specifically so a ragged last row still catches the D-pad. Their
  `ContinuumTheme.swift` token-file shape (one `#if os(tvOS)`, inside a token type, not scattered
  per view) is the model `KinoPubUI/Layout/` followed.

## Open questions this report left unverified

Whether the ragged-`LazyVGrid` D-pad trap actually reproduces in this app's catalog grid; whether
SwiftUI gives tvOS the 60/80pt safe-area inset automatically or it must be added by hand; whether
`scrollTargetBehavior(.viewAligned)` fights tvOS focus-scrolling; `.buttonStyle(.card)` vs
`.borderless` for posters. Treat as unresolved unless a feature doc says otherwise.
