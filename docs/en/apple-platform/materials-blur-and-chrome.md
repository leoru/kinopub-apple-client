# Materials, blur, and chrome

## Evergreen

- Liquid Glass on tvOS 26+: `glassEffect`, `GlassEffectContainer`, `glassEffectID` / morphing,
  `.buttonStyle(.glass)` / `.glassProminent`, `scrollEdgeEffectStyle`, `safeAreaBar`,
  `ConcentricRectangle`. Older Apple TV hardware may keep prior appearance.
  (`backgroundExtensionEffect` as *shell* chrome is banned here — contained blur bleed is open;
  see Pitfalls.)
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
- **A blur that has to follow a scroll is a scrubbed material, not `.blur(radius:)`.** `.blur`
  filters an already-rendered frame; a `UIVisualEffectView` driven by a **paused**
  `UIViewPropertyAnimator` (`startAnimation()` → `pauseAnimation()`, then set `fractionComplete`)
  is the sanctioned way to interpolate a material, and `alpha` on an effect view is not a
  substitute. tvOS detail hero only — on iOS the nav bar's own material already does this job, and
  on macOS a scrubbed blur fights the fixed-toolbar convention. See
  [detail-page-choreography](../plans/detail-page-choreography.md).
- Hero Play CTAs are **not** `.glassProminent` — white pill + translucent circles.
- **`backgroundExtensionEffect` as shell chrome is banned** (Home / page / under
  `TabView(.sidebarAdaptable)`). Sidebars **displace** content — there is nothing to bleed under.
  **Contained** use (card / hero still → system mirror+blur into that view's own `safeAreaInset`)
  is a different axis; prototype in `HeroBleedVariants` before promoting. See the pitfall.
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
- **`backgroundExtensionEffect` is not glass.** Apple's docs: the view is duplicated into
  mirrored, blurred copies on edges with available safe area. Two different jobs:
  - **Shell / sidebar / nav (banned here).** Canonical WWDC use is the detail column of a
    `NavigationSplitView` bleeding under an *overlaying* sidebar. This app uses
    `TabView(.sidebarAdaptable)` that **displaces** content — tried on Home, mirrored error
    placeholders into chrome, removed. Do not put it on the page or under the tab sidebar.
  - **Contained image blur bleed (open).** Same API on a *clipped* still with its own
    `safeAreaInset` (nilcoalescing card pattern) soft-extends art for titles / hero chrome.
    That is blur, not navigation. Gate on real artwork (never an error placeholder). Prototype
    before shipping into `MediaItemHeroView`.
