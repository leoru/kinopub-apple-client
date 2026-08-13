---
name: apple-chrome
description: Working on glass, materials, blur, scroll-edge effects, toolbars, tab bars, sidebars, search, navigation structure, or layout containers and card sizing — mostly iOS / iPadOS / macOS, plus the shared shell. Use before adding a material, a blur, a tab, a search field, or a new container.
---

# Chrome: glass, materials, navigation, containers

Baseline is **26.0** on every platform; mark 27-only API explicitly. Web DocC sometimes omits tvOS
availability — prefer the SDK `.swiftinterface` when unsure.

## Glass and materials

**Facts**

- Liquid Glass on 26+: `glassEffect`, `GlassEffectContainer`, `glassEffectID` / morphing,
  `.buttonStyle(.glass)` / `.glassProminent`, `scrollEdgeEffectStyle`, `safeAreaBar`,
  `ConcentricRectangle`. Older Apple TV hardware may keep the prior appearance.
- On tvOS many elements adopt glass **on focus**; glass never replaces focus indication.
- **Glass samples the content behind it.** A flat page fill gives it nothing and degrades it to a
  matte slab — put artwork or rails under the chrome, not a colour, when the glass should read.
- tvOS has **no semantic background colours** (`systemBackground` and friends are
  `API_UNAVAILABLE(tvos)`) — the platform expects the app to bring its own backdrop.
- Translucency conveys hierarchy; do not stack light translucent surfaces on each other.
- `GlassEffectContainer` is the one glass API that is about *performance*: many independent
  `.glassEffect` calls outside a container degrade rendering. Keep container spacing ≤ the inner
  stack's spacing, or shapes blend at rest.

**Ours**

- **All `glassEffect` goes through `kinoGlass(in:tint:interactive:)` / `kinoGlassGroup`**
  (`KinoPubUI/DesignSystem/KinoGlass.swift`), never the raw API at a call site. The helper degrades
  to an opaque fill (`Color.KinoPub.glassSubstitute`) under Reduce Transparency / Increase Contrast.
- **Glass over live video uses `kinoPlayerGlass`** — backdrop sampling re-blurs the covered region
  every video frame, so `DevicePower.isLowPowerAppleTV` (utsname → A12-class boxes) substitutes an
  opaque fill there.
- `.buttonStyle(.glass)` / `.glassProminent` are a **separate**, fully system-owned path and
  deliberately do not route through `KinoGlass`.
- Actual glass in the app today is small — three `.buttonStyle(.glass)` call sites. Do not assume
  the chrome is glass end to end.
- Nothing currently has two adjacent `kinoGlass` surfaces, so `kinoGlassGroup` exists for the next
  one. Do not wrap non-glass content in it.
- **Hero Play CTAs are not glass** — white pill + translucent circular secondaries.
- **No page-level material behind Home.** The old `.background(.ultraThickMaterial)` sat on top of
  the page background doing nothing but lightening it.
- **The navigation bar is left to the system.** On 26 it is already Liquid Glass with the
  scroll-edge effect; do not set `containerBackground(.ultraThickMaterial, for: .navigation)` or
  stack a material behind the page to "help" it. It reads as non-native immediately.

## Blur

- **Private `CAFilter` `variableBlur`** (thin in-repo helper) for Music/Journal-style progressive
  blur over **static** hero / banner art. The Metal `ProgressiveBlur` path is gone.
- **tvOS + macOS: no variable blur over video. iOS + iPadOS: blur over video is fine.**
- **A blur that has to follow a continuous gesture is a scrubbed material, not `.blur(radius:)`.**
  `.blur` filters an already-rendered frame; a `UIVisualEffectView` driven by a **paused**
  `UIViewPropertyAnimator` (`startAnimation()` → `pauseAnimation()`, then `fractionComplete`) is the
  way to interpolate a material, and `alpha` on an effect view is not a substitute.
- **But animate the mask, not the material.** SwiftUI *can* animate a material — you animate the
  mask in front of it (a `LinearGradient` whose stop opacities animate). Never fade a material with
  `.opacity()`: that draws the full-strength effect semi-transparently instead of weakening it. The
  detail hero uses this, between two discrete states — it does **not** scrub.
- Full-screen `layerEffect` blur recomputed on every focus move is a performance footgun. Tie blur
  to image identity changes, not to focus ticks.
- macOS `.behindWindow` materials can grey out cards — validate carefully.

### `backgroundExtensionEffect` — two different jobs

Apple's docs: the view is duplicated into mirrored, blurred copies on edges with available safe area.

- **Shell / sidebar / nav — banned here.** The canonical WWDC use is a `NavigationSplitView` detail
  column bleeding under an *overlaying* sidebar. We use `TabView(.sidebarAdaptable)`, which
  **displaces** content — there is nothing to bleed under. Tried on Home; it mirrored error
  placeholders into chrome and was removed.
- **Contained image blur bleed — open.** The same API on a *clipped* still with its own
  `safeAreaInset` soft-extends art behind titles or hero chrome. That is blur, not navigation. Gate
  it on real artwork (never an error placeholder) and prototype in `HeroBleedVariants` first.

Also: do not fake bleed with `.ignoresSafeArea(.horizontal)` on macOS — it draws the page under the
sidebar and clips the first poster. `MediaItemView` deliberately ignores **top only** there.

### Scroll-edge effect

`scrollEdgeEffectStyle(.automatic, for: .top)` on the app's `ScrollView`-backed grids and rows
(`ContentItemsListView`, `MediaCardsListView`, `MediaRowsView`). `List`-backed screens get it
automatically; a plain `ScrollView` does not. Gated `#if !os(tvOS)` — no floating bar sits over
those tvOS screens for content to slide under. Not applied to the detail page's hero scroll, which
hides the nav-bar background on purpose so artwork runs to the top edge.

## Navigation, tabs, search

**Facts**

- One `NavigationStack` per tab, with a unified route enum + destination registry.
- **iPhone / iPad:** `Tab(role: .search)` pins Search on the **trailing** edge. Do not use legacy
  `.tabItem` for Search — that keeps it as a normal left-side tab.
- **tvOS:** Search is a normal **first** tab, left of Home. Do **not** use `Tab(role: .search)`
  there — the search role pins trailing.
- **tvOS tab bar shape is icon · text · text · text · text · icon**: Search and Settings are
  glyph-only, browse tabs are words. Pass a bare `Image` / `Text` as the `Tab` label —
  `Tab("Title", systemImage:)` gives every tab an icon+label chip, which is the thing to avoid.
  Glyph tabs still carry `.accessibilityLabel`. **No in-content Back button on tvOS**: Search is a
  tab, so the way out is up into the tab bar, and a chevron row above a grid also steals the first
  focus target on entry.
- **macOS:** no Search tab and no Settings tab in the library window. Settings is the Settings window
  (`⌘,` / App menu). Search is a **compact trailing toolbar field** (Finder/Photos):
  `.searchable(..., placement: .toolbar)` on each tab's `NavigationStack` — **never** on `TabView`,
  and never `.toolbarPrincipal` (giant centre field). Return opens the results surface. Leading Back
  returns to the previous tab when Search was entered from browse/toolbar/filter; once a title is
  pushed, the system stack owns that slot. Filters on Search results stay in `.accessoryBar`.
- `.toolbar(removing: .sidebarToggle)` must be applied to the **sidebar column's content**, not to
  the `NavigationSplitView` — on the split view it is silently ignored (probe-confirmed on screen,
  macOS 27, not from docs).
- `TabViewCustomization` / tab hide-reorder are not wired on macOS production, and those APIs are
  **unavailable on tvOS**.
- `.tabBarMinimizeBehavior` scroll values are effectively iPhone-oriented, and `.never` is iOS 26+
  only — unavailable on tvOS/macOS.
- tvOS search suggestions are text-oriented; do not expect poster-rich suggestion rows.

**Ours**

- Shipping shell is the classic system `TabView` everywhere, until `.sidebarAdaptable` / a locked
  sidebar is done the **system** way: tvOS `.tabBarOnly` Search · Home · Movies · Shows · Library ·
  Settings; macOS `.tabBarOnly` Home · Movies · Shows · Library + toolbar search; iPad the same plus
  Settings and a trailing Search role; iPhone the same on a bottom bar.
- **No tab-bar pinning requirement.** Take what the system does on scroll; do not chase it with
  `.toolbar(.hidden, for: .tabBar)`, minimize behaviours, or a custom bar over content.
- Re-selecting a tab pops that tab's stack to root.
- Zoom: `matchedTransitionSource` / `navigationTransition(.zoom)` on **iOS/tvOS** from poster,
  banner and cast. On **macOS** the API may be unavailable — say so rather than claiming transitions
  "everywhere".
- `.sidebarAdaptable`, locked sidebar chrome and Home segmentation are **parked, not discarded**
  (prototypes in `Views/UILab/`). Open problems: sidebar toggle/hide/edit without fighting HIG, and
  `List(selection:)` with associated-value tabs. Finish it with public Tab/toolbar APIs — do **not**
  invent Button-row sidebars, and do not paper over gaps with private UIKit/AppKit hacks.
- Superseded, do not revive: Netflix-style Home focus-preview (`showsFeaturedPreview`), hand-rolled
  multi-stack tab shells.

## Layout and containers

- Prefer system containers: `HStack` / `VStack` / `ZStack`, then `LazyHStack` in a `ScrollView` for
  shelves, `LazyVGrid` / `LazyHGrid` for galleries, `List` / `Form` where you want system chrome.
  Start eager; go lazy when profiling says so.
- `containerRelativeFrame(.horizontal, count:spacing:)` replaces hard-coded card widths off tvOS.
  On tvOS the column count comes from a target card width — see the `tvos-surface` skill.
- Also useful: `ViewThatFits`, `contentMargins`, `safeAreaPadding`, `scrollTargetBehavior` /
  `scrollTargetLayout`, custom `Layout`.
- **tvOS 27 enables Dynamic Type systemically.** Hard-coded font sizes and fixed frames are the
  named cause of breakage (WWDC26 session 221) — `.system(size:)` never scales, so our text stays
  put while system chrome grows around it.
- Home banner: contained 16:9 cards (~2 columns wide, full width on phone), view-aligned snap.
- Detail: one vertical `ScrollView`. The old offset "slideshow" and focus-bridge detail model are
  **superseded**.
- Pitfalls: fixed `frame(width:height:)` forests break Dynamic Type and multiplatform scaling; inert
  spacers above the first focusable row steal Up and trap focus in the tab bar; do not add a grid
  library when `LazyVGrid` + `containerRelativeFrame` suffice.

## Cross-platform

- Raising the deployment target removed little `#if os` by itself — most branches are permanent
  (API missing on a platform, or 10-foot vs pointer design). Prefer `@available` cleanup and
  file-splitting over nested `#if` forests.
- macOS owns scenes, `CommandGroup`, window style, and window tabbing (turn automatic tabbing off if
  the player must not merge into the library window).
- Light appearance is a dedicated stage — do not half-enable it early.
- **Verify high-risk UI on each platform you touched**, not tvOS alone. Marking work complete after a
  tvOS-only compile while the macOS sidebar or artwork is broken is a repeat offence here.
