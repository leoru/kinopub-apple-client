# 02 — Liquid Glass and materials

Condensed English summary of a 2026-07-25 research pass, baseline 26.0 (tvOS/iOS/iPadOS/macOS),
27-only noted separately. Every API claim was originally verified against Apple's docs; current
guidance lives in
[`.claude/skills/tvos-surface/SKILL.md`](../../../.claude/skills/apple-chrome/SKILL.md).
This report's core recommendation — a single `KinoGlass` helper with accessibility degradation —
**landed** in this session as `KinoPubUI/DesignSystem/KinoGlass.swift`. Russian original:
`02-liquid-glass.ru.md` (gitignored, local only).

## TL;DR (at the time)

- **Liquid Glass exists on tvOS in full**: `glassEffect`, `GlassEffectContainer`, `glassEffectID`,
  `glassEffectUnion`, `glassEffectTransition`, `Glass.regular/.clear/.identity`, `.tint()`,
  `.interactive()`, `.buttonStyle(.glass/.glassProminent/.glass(_:))`, `scrollEdgeEffectStyle`,
  `backgroundExtensionEffect()`, `safeAreaBar`, `ConcentricRectangle` — all tvOS 26.0. Only
  `ToolbarSpacer`/`SpacerSizing` are unavailable on tvOS (no tvOS toolbars).
- **Hardware ceiling**: tvOS 26 release notes state design updates "are not carried forward to
  Apple TV 4K (1st generation) and older models." HIG: only Apple TV 4K (2nd gen)+ render Liquid
  Glass; older boxes keep their prior appearance. Code is valid everywhere; the effect just doesn't
  draw on old hardware.
- **On tvOS, glass defaults to focus-driven**: "Certain interface elements, like image views and
  buttons, adopt Liquid Glass when they gain focus" (HIG). The exception is `.glass`/`.glassProminent`
  buttons, which render glass regardless of focus. **Glass never replaces focus indication** — scale
  and inversion still need to be handled explicitly.
- **No 1:1 native replacement for a hand-rolled progressive/variable blur.** SwiftUI has no general
  "blur that ramps across a view." Two narrower tools cover the app's actual use cases instead:
  `scrollEdgeEffectStyle(.soft/.hard, for:)` (blur under a pinned bar) and
  `backgroundExtensionEffect()` (mirror + blur into safe area). The shader wasn't kept because it had
  a native equivalent — it was kept because both real use cases turned out to be solvable another
  way (see below).
- Buttons over bright artwork: HIG's recipe is `Glass.clear` for elements over media, plus (if the
  backdrop is bright) a 35% dark dimming layer underneath. For the primary action: `.glassProminent`
  with color in the *background*, not the label.
- Apple explicitly warns against: glass in the content layer; too much glass in a row; glass on top
  of glass; custom backgrounds on bars/sidebars/toolbars; multiple `GlassEffectContainer`s where one
  would do.
- Apple's Landmarks sample (background-extension hero, one container per badge group, `.glass` on
  toggles) does **not** ship for tvOS — borrow the ideas, not the `NavigationSplitView`/`inspector`
  code.

## What was available at baseline 26

Core: `glassEffect(_:in:)`, `Glass` (`.regular`/`.clear`/`.identity`, `.tint()`, `.interactive()`),
`GlassEffectContainer`, `glassEffectID`/`glassEffectUnion`/`glassEffectTransition`,
`.buttonStyle(.glass/.glassProminent/.glass(_:))`, `ConcentricRectangle` — all tvOS 26.0.
`UIGlassEffect` is the UIKit equivalent, also tvOS 26.0. `ToolbarSpacer`/`SpacerSizing` have no tvOS.

Scroll/background: `scrollEdgeEffectStyle(_:for:)` + `ScrollEdgeEffectStyle` (`.automatic/.hard/.soft`),
`scrollEdgeEffectHidden`, `backgroundExtensionEffect()`, `safeAreaBar` — all tvOS 26.0.

Plain materials (not Liquid Glass, content-layer): `Material` (`.ultraThin`…`.ultraThick`, tvOS
15.0), `BackgroundProminence` (tvOS 17.0). `MaterialActiveAppearance` (tvOS/iOS 18.0) only means
something on macOS window-focus state — tvOS/iOS materials are always active. `Color.ResolvedHDR`
(26.0) is about HDR headroom, not control legibility.

27-only: nothing new on this topic. Liquid Glass appearance in 27 updates automatically on rebuild
with the new SDK; the `UIDesignRequiresCompatibility` Info.plist key is the rollback valve if needed.

HIG placement rules: **do** use glass for the functional layer over content (nav, bars, the page's
most important actions, controls over media via `Glass.clear`). **Don't**: glass in the content
layer, glass stacked on glass, custom bar/sidebar/toolbar backgrounds, color on more than one
control at once. Systems components adapt to Reduce Transparency / Increase Contrast on their own —
custom glass does not, and must be tested under both.

## What this became in the app

- **`KinoGlass.swift`** (this session): the single place `glassEffect` is written —
  `kinoGlass(in:tint:interactive:)` / `kinoPlayerGlass(in:tint:)`, degrading to an opaque fill under
  Reduce Transparency, Increase Contrast, or (for the player variant) low-power Apple TV hardware.
  This directly followed the pattern this report flagged in silo-apple's `SiloGlass.swift` /
  `DevicePower.swift`.
- The Metal `variableBlur` shader was **kept**, not deleted — see
  [`materials-blur-and-chrome.md`](../../../.claude/skills/apple-chrome/SKILL.md) for the
  current, different reasoning (Music/Journal-style progressive blur over static hero art has no
  native equivalent; this report's proposed small-buffer alternative for the card-footer case was
  judged good enough only for that narrower spot).
- `backgroundExtensionEffect()` was tried on Home and then **removed entirely** — see
  [`materials-blur-and-chrome.md`](../../../.claude/skills/apple-chrome/SKILL.md) Pitfalls.
  This report's assumption that it would be a safe "native hero blur" recipe did not hold: the app
  has no `NavigationSplitView`, and the effect mirrored unrelated content (including error
  placeholders) into chrome that was never underneath it.

## tvOS pitfalls worth keeping

- Old Apple TV hardware (pre-4K-2nd-gen) never renders Liquid Glass — don't design UI that only
  works *with* the glass.
- Glass ≠ focus signal on tvOS except for `.glass`/`.glassProminent`, which render identically
  focused or not — add scale/inversion yourself.
- One `GlassEffectContainer` per related group, not one per element — too many containers or
  ungrouped `.glassEffect` calls degrade performance.
- `glassEffect` goes **after** other appearance modifiers.
- Container `spacing` larger than an inner stack's own spacing makes glass shapes blend together at
  rest — keep container spacing ≤ stack spacing unless merging is wanted.
- **Glass over playing video is expensive**: backdrop sampling re-blurs the covered video region
  every frame, which A12-class Apple TVs pay for as a visible spike. This became `kinoPlayerGlass`'s
  reason to exist.
- SwiftUI `Material` exists on tvOS (15.0+); the UIKit `systemMaterial*` blur styles do not — a
  real UIKit/SwiftUI capability gap on this platform.

## What was borrowed

**silo-apple**: `SiloGlass.swift`'s single-helper pattern and its video-aware substitute path;
`DevicePower.swift`'s `utsname()` → `AppleTV<major>` hardware check (both became this session's
`KinoGlass.swift` / `DevicePower.swift`); the hero-backdrop lesson that a hard `.clipped()` on a
fixed-height frame kills `backgroundExtensionEffect` bleed; a bottom `LinearGradient` fade instead
of a blur for the hero base fade.

**Rivulet**: a clean example of `.glassEffect(.regular.interactive(), in:)` on a popup; the
dimming-under-glass pattern (30% black fill + glass on top, HIG recommends 35%); an explicit
anti-pattern to avoid — material *underneath* glass on the same surface, which is glass-on-glass.

## Open questions this report left unverified

Whether `scrollEdgeEffectStyle` is visible at all on tvOS (no floating bars on a plain
`NavigationStack` screen — silo-apple assumes not and suppresses it there); what
`backgroundExtensionEffect()` actually does in tvOS's overscan safe area (this was later tested in
practice on Home and rejected — see above, so this specific unknown is now resolved: don't use it);
whether tvOS's `TabView(.sidebarAdaptable)` sidebar gets glass out of the box given `.buttonStyle(.plain)`
call sites nearby; the real performance cost of glass over a continuously playing hero trailer on a
2nd-generation Apple TV 4K.
