# 01 — Foundation and UI stabilization

**Status:** In progress  
**Goal:** Local metadata/image continuity, stable navigation/focus/materials, and finish-or-gate
current auxiliary work so the app feels instant and native.

## Accepted behavior

- Stale-while-revalidate for Home/Library summary rows (`ContentStore`).
- Contained Home banner shelf; private `variableBlur` on static art; system material under sidebar.
- Unified `Route` / `RouteDestination`; single `PlaybackSession`.
- Continuity beats blank: card→detail carries known item + artwork when available.
- Exact skeletons only on true cold loads; Search empty poster grid allowed for focus landing.

## Checklist

- [x] Home/Library list cache + disk snapshots (`ContentStore` / `RowSnapshotStore`)
- [x] Banner shelf + delete Netflix focus-preview path
- [x] Home banner gated by `FeatureFlags.homeBannerEnabled` (off by default; off skips sampling + artwork loads)
- [x] Private `variableBlur` replaces Metal progressive blur
- [x] Unified routes + zoom transitions (iOS/tvOS)
- [x] App-scoped `PlaybackSession`
- [ ] Paginated Movies/Series/Search grids participate in the same store model
- [ ] Item-facts TTL cache extension (`MetadataCache`) for kino.pub details + enrichment
- [ ] Shared image pipeline (dedupe, disk, prefetch, palette) — evaluate Nuke vs finish in-house
- [ ] Card→detail handoff always seeds hero from known artwork (no bare background when card had art)
- [ ] Finish or feature-gate incomplete auxiliary chrome from the modernization pass
- [ ] High-risk surfaces marked validation-pending until Device Hub / macOS visual checks

### Atoms and duplication

- [ ] One `AsyncImage` atom instead of ~15 call sites
- [ ] De-duplicate the two initials-avatar implementations into one atom
- [ ] Fold the episode card into the shared caption + progress structure — behavioural identity
  (same focus animation, caption reveal, progress semantics, watched treatment) is the acceptance
  criterion; only aspect and filled slots may differ
- [ ] Collapse the 16 custom `ButtonStyle` types (separate pass)
- [ ] `MediaItemInfoColumns` → `Grid` / `GridRow` + `gridColumnAlignment(.leading)`

### Accessibility and type

- [ ] `MediaCardView` gets an `accessibilityLabel`
- [ ] `RatingBadgeView` encodes tier **only** by colour — add a non-colour differentiator
- [ ] Replace remaining `.system(size:)` calls with `TypeScale` text styles. **Measured 2026-08-05:**
  80 call sites — 67 in the app target (30 of them in `MediaItemDetailSections.swift` alone,
  10 in `PersonItemsView`, 6 each in `SeasonsRailView` / `MediaItemHeroView`) and 13 in `KinoPubUI`.
  Not all are wrong: `TypeScale.swift` itself and preview files legitimately name sizes. Audit
  rather than sweep blindly, and split package from app target so the diff stays reviewable.
- [ ] Retire `Font.KinoPub` (`KinoPubUI/Font/Font+Extension.swift`) — superseded by `TypeScale`
- [ ] `@ScaledMetric` on every square / hairline dimension (portraits, circular buttons, tab icons).
  **Measured 2026-08-05:** 1 use in the whole codebase.

**Why this is not cosmetic:** tvOS 27 turns on Dynamic Type system-wide, and Apple names hard-coded
font sizes and fixed frames as the direct cause of breakage (WWDC26 session 221). `.system(size:)`
never scales, so the app's text stays put while system chrome around it grows — a worse failure than
not supporting it at all. See [layout-and-containers](../apple-platform/layout-and-containers.md).

### Focus, navigation, chrome

- [ ] `MediaItemHeroView` — four buttons share `.focused($focus, equals: .heroOther)`
- [ ] `MediaItemView` two-slide `.offset(y:)` + `.clipped()` "slideshow"
- [ ] `TabsNavigationView` — 630 lines across three near-identical platform trees
- [ ] Detail hero height → `containerRelativeFrame(.vertical)` instead of hard-coded values
- [ ] Card → detail transition: prefer the default / system morph before anything custom
- [ ] tvOS tab background via `containerBackground(for: .tabView)` where useful
- [ ] `LibraryFiltersBar` / `MainView` material cleanups — system glass only where it matches
  scroll / nav chrome, through `kinoGlass`
- [ ] **`GlassEffectContainer` where glass surfaces sit together.** Measured 2026-08-05: zero uses.
  This is the one glass API that is about *performance*, not looks — Apple warns that many
  independent `.glassEffect` calls outside a container degrade rendering. Current glass: 1
  `kinoGlass`, 2 `kinoGlassRim`, 3 `.buttonStyle(.glass)`. The hero action row is the obvious first
  container. Keep container spacing ≤ the inner stack's spacing or shapes blend at rest.
- [ ] **`scrollEdgeEffectStyle` on scrolling surfaces.** Measured 2026-08-05: zero uses. This is
  what gives the native "content slides under the bar" treatment on iOS. Expected to be a no-op on
  tvOS (no floating bars on a plain `NavigationStack` screen) — verify rather than assume, and
  suppress it there if so.
- [ ] Apply the `variableBlur` helper on detail / Home hero and banner overlays
- [ ] Bring poster overlays back on tvOS behind an explicit `.hoverEffect(.highlight)`
- [ ] Banner polish: page dots / L-R affordances only if it becomes a real carousel

### Observation model

**Measured 2026-08-05, before the pilot:** zero `@Observable`; 27 `ObservableObject`, 117
`@Published`, 39 `@StateObject`, 55 `@EnvironmentObject`.

- [x] Pilot `@Observable` on leaf models with no Combine chains — `ErrorHandler`, `WindowSettings`,
  `ProfileModel` — to establish the house pattern before touching anything load-bearing. Pattern
  settled below.
- [ ] `HomeCatalog` — five `@Published` on one object means a change to `isLoaded` re-evaluates the
  whole rows screen. Highest-value single conversion
- [ ] `NavigationState` **last** — `NavigationStack(path:)` needs a `Binding`, so it wants
  `@Bindable`, and it is the most connected object in the app
- [ ] `AuthState`, `PlayerManager`, and anything still driven by a Combine `$property` chain —
  after the two above prove the pattern holds under more fan-out than a leaf model

**The settled pattern**, from the
[`ErrorHandler`](../../../KinoPubAppleClient/States/Error/ErrorHandler.swift) /
[`WindowSettings`](../../../KinoPubAppleClient/Custom/WindowSettings.swift) (macOS-only) /
[`ProfileModel`](../../../KinoPubAppleClient/Views/Profile/ProfileModel.swift) pilot. Mixed
`ObservableObject`/`@Observable` is supported by SwiftUI; migrate type by type, not in one pass.

- `final class X: ObservableObject` → `@Observable final class X`; drop every `@Published`. A
  plain `var` streams through the macro's own access tracking; `didSet`/`willSet` on a stored
  property still fire normally under `@Observable`.
- Root owner: `@StateObject var x = X()` → `@State var x = X()`.
- Injection: `.environmentObject(x)` → `.environment(x)`. Consumer: `@EnvironmentObject var x: X`
  → `@Environment(X.self) var x`. `@Environment(X.self)` crashes if nothing was injected for that
  type on that branch of the view tree — re-check every injection point the model reaches
  (`RootView`, `TabsNavigationView`, the app struct, any scene/sheet that re-injects for a
  presented root) when migrating a type, not just the one call site you're editing.
- Binding into an `@Observable` property read via `@Environment`: there is no `$` projection off
  `@Environment` itself. Shadow it locally as the first statement of `body`:
  `@Bindable var x = x` — then `$x.property` works exactly like it did off `@ObservedObject`.
  Where a child view just receives the object as a parameter (not via `@Environment`), skip the
  shadow and mark the stored property `@Bindable var x: X` directly — same effect, no
  `@ObservedObject` needed.
- Read-only pass-down with no binding derived from it in that view → plain `let x: X`. SwiftUI's
  re-render tracking follows property *reads* inside `body`, not the wrapper, so a plain `let`
  observes correctly as long as the object was obtained through the environment/parameter chain
  that actually holds it.

**The trap, resolved:** 14 view models are constructed through
`init(model: @autoclosure @escaping () -> X) { _model = StateObject(wrappedValue: model()) }` so
`StateObject.init(wrappedValue:)` evaluates them lazily, exactly once. `State.init(wrappedValue:)`
has **no** autoclosure overload — a naive `@StateObject` → `@State` swap re-creates the model on
every view `init` and throws it away. Decide per model, don't default to either side:
  - `ProfileModel.init` only stores references and does one synchronous `UserDefaults` read — no
    `Task`, no network call. Eager construction is genuinely fine, so the autoclosure came off:
    `init(model: X) { _model = State(wrappedValue: model) }`, and call sites
    (`ProfileView`, `SettingsSceneHost` in the macOS Settings window) now pass the value directly.
    The discarded extra allocations on re-render cost nothing worth guarding against.
  - A model whose `init` starts a `Task`, opens a connection, or does anything else with a
    side effect needs the laziness kept on purpose: `@State private var model: X?`, constructed
    once inside `.task`/`.onAppear` guarded on `nil`, not via a property initializer. Applies to
    the remaining 13 — judge each on its own merits when its turn comes, same as `ProfileModel` was.

`@Observable` is a **precondition** for granular invalidation, not a performance win on its own —
the granularity comes from how data is keyed, not from the macro. See
[local-caching](../plans/local-caching.md) for the `ContentStore` side of this.

**Known ceiling, so nobody plans around it:** `TabViewCustomization` limits are documented in the
plan — check there before designing sidebar customization.

## Folded from plans

Open items from [`docs/en/plans/local-caching.md`](../plans/local-caching.md) §2 and grid pagination
belong here — not in README minutiae. The UI items above were moved out of
[`modernization.md`](../plans/modernization.md) when that plan was closed to pure history; the plan
still holds the detailed rationale and file:line references for each.

## Validation

- [ ] Tab return shows cached rows without blank flash
- [ ] macOS sidebar bleed / banner aspect / wide artwork load
- [ ] tvOS focus on banner → first shelf without dead space
