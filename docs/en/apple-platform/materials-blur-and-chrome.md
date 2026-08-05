# Materials, blur, and chrome

## Evergreen

- Liquid Glass on tvOS 26+: `glassEffect`, `GlassEffectContainer`, `glassEffectID` / morphing,
  `.buttonStyle(.glass)` / `.glassProminent`, `scrollEdgeEffectStyle`, `safeAreaBar`,
  `ConcentricRectangle`. Older Apple TV hardware may keep prior appearance.
  (`backgroundExtensionEffect` is part of the same release but is **banned here** — see Pitfalls.)
- On tvOS, many elements adopt glass **on focus**; glass does not replace focus indication.
- Glass samples the **content** behind it. A flat page fill gives it nothing and degrades it to a
  matte slab — put artwork / rails under the chrome, not a colour, when the glass should read.
- tvOS has **no semantic background colours** (`systemBackground` and friends are
  `API_UNAVAILABLE(tvos)`) — the platform expects the app to bring its own backdrop.
- Toolbar / list chrome: prefer **public** scroll-edge + materials over custom blur bars.
- Translucency conveys hierarchy; do not stack light translucent surfaces on each other.
- Respect `prefers-reduced-transparency` equivalents via system materials.

## Project decisions

- **All `glassEffect` goes through `KinoPubUI/DesignSystem/KinoGlass.swift`.** Call sites write
  `kinoGlass(in:tint:interactive:)`, never `glassEffect` directly. The helper degrades to an opaque
  fill (`Color.KinoPub.glassSubstitute`) under Reduce Transparency or Increase Contrast.
- **Glass over live video uses `kinoPlayerGlass`.** Backdrop sampling re-blurs the covered region
  every video frame; `DevicePower.isLowPowerAppleTV` (utsname → `AppleTV<major>`, A12-class boxes)
  substitutes an opaque fill there.
- The system button styles `.buttonStyle(.glass)` / `.glassProminent` are a **separate** path — fully
  system-owned, they degrade on their own, and they deliberately do not route through `KinoGlass`.
- Actual glass in the app today is small: three `.buttonStyle(.glass)` call sites, and nothing else.
  Do not assume the chrome is already glass end to end.
- **Private `CAFilter` `variableBlur`** (thin in-repo helper) for Music/Journal-style progressive blur
  over **static** hero / banner art. Metal `ProgressiveBlur` path removed.
- **tvOS + macOS:** no variable blur over **video**. **iOS + iPadOS:** blur OK over video too.
- Hero Play CTAs are **not** `.glassProminent` — white pill + translucent circles.
- **`backgroundExtensionEffect` is not used anywhere, on any platform.** Removed from Home. Our
  sidebars are meant to **displace** content, not float over it, so nothing needs to bleed
  underneath. See the pitfall below before reintroducing it.
- **No page-level material behind Home.** The old `.background(.ultraThickMaterial)` sat on top of
  the page background doing nothing but lightening it.
- **The navigation bar is left to the system.** On 26 it is already Liquid Glass with the
  scroll-edge effect. Do not set `containerBackground(.ultraThickMaterial, for: .navigation)` or
  stack a material behind the page to "help" it — that reads as non-native immediately.
- Do not fake bleed with `.ignoresSafeArea(.horizontal)` on macOS: it draws the page under the
  sidebar and clips the first poster / episode. `MediaItemView` deliberately ignores **top only**
  there.
- macOS `ProgressiveBlur` / material using `.behindWindow` can grey out cards — validate carefully.
- **`GlassEffectContainer` goes through `kinoGlassGroup` (`KinoGlass.swift`)**, the same "no
  raw glass API at call sites" rule as `glassEffect` itself. As of this writing nothing in the
  shipped app has two or more `kinoGlass`/`kinoPlayerGlass` surfaces sitting adjacent — the hero
  action row is hand-rolled translucent circles, not `glassEffect` (see above); `.buttonStyle(.glass)`
  is the separate system-owned path. The helper exists for the next surface that needs it; do not
  wrap non-glass content in it.
- **`scrollEdgeEffectStyle(.automatic, for: .top)` on the app's `ScrollView`-backed grids/rows**
  (`ContentItemsListView`, `MediaCardsListView`, `MediaRowsView`) — `List`-backed screens (Settings,
  Downloads) already get this automatically; a plain `ScrollView` does not, so poster grids and the
  Home rail need it explicit. Gated `#if !os(tvOS)`: no floating bar sits over these tvOS screens
  for content to slide under (plain `NavigationStack`, no search/nav chrome pinned above the grid),
  matching the reference app's approach. Not applied to `MediaItemView`'s hero scroll — that page
  hides the nav bar background on purpose (`toolbarBackground(.hidden, ...)`) so artwork runs to
  the top edge; there is no bar for the effect to key off.

## Superseded

- Research suggestion to delete hero blur entirely / gradient-only heroes.
- Research quick-win of glass on detail hero Play buttons.
- Custom `ultraThickMaterial` toolbars inventing "homemade glass" instead of system sidebar behavior.

## Pitfalls

- Full-screen `layerEffect` blur recomputed every focus move is a performance footgun.
- Blur must be tied to image identity changes, not every focus tick.
- **`backgroundExtensionEffect` is not glass, and this app must not use it.** Apple's own docs: the
  view "will be duplicated into mirrored copies which will be placed around the view on any edge
  with available safe area", then blurred. It exists for the **detail column of a
  `NavigationSplitView`**, so artwork bleeds under an *overlaying* sidebar or inspector.
  - This app has no `NavigationSplitView` at all — `TabView(.sidebarAdaptable)` everywhere.
  - A tvOS sidebar is an **overlay** and behaves differently again; the native Apple TV app does
    not mirror anything.
  - The product intent is that a sidebar **displaces** content, so there is nothing to hide behind.
  - Because it wraps whatever the page currently renders, a failed or empty load gets the **error
    placeholder mirrored** into the chrome. That alone should have caught it.
  - "Gate it on an actual sidebar" is not the fix. Do not reintroduce it.
