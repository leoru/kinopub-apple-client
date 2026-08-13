# 08 — Performance and state architecture

Condensed English summary of a 2026-07-25 research pass, baseline 26.0, read-only against the code
at the time. Current guidance is distributed across
[`.claude/skills/tvos-surface/SKILL.md`](../../../.claude/skills/apple-chrome/SKILL.md)
and the data-continuity policy. This report's diagnosis of the hero-preview blur cost is the direct
ancestor of the `variableBlur` decisions recorded in
[`materials-blur-and-chrome.md`](../../../.claude/skills/apple-chrome/SKILL.md), and its
`ContentStore`/stale-while-revalidate design is the direct ancestor of what shipped as `ContentStore`
per [`01-foundation-continuity.md`](../../../ROADMAP.md). Russian original:
`08-performance.ru.md` (gitignored, local only).

## TL;DR (at the time)

- **The progressive blur was expensive from three multiplying factors, not "the shader" alone**: a
  full-screen `layerEffect` at 25 samples/pixel recomputed on every composited frame; `.id(url)`
  giving the backdrop view a **new identity on every focus move** (fresh load, fresh decode, fresh
  layer rasterization); and a 450ms crossfade that meant holding Right on the remote kept 2–4
  full-screen variable-blur layers alive simultaneously. Fixable **without Metal at all** — the
  repo already had the right pattern (`MediaItemView`'s small-buffer ambient background) sitting
  unapplied to the Home backdrop.
- **`@Observable` migration: yes, but as a precondition for other fixes working, not a performance
  fix by itself.** Granular invalidation — only re-rendering the views that actually read the
  changed value — is the only way focus movement stops rebuilding 120 cards' worth of view identity.
  Just swapping the macro onto existing classes without restructuring how data is keyed would give
  little; the granularity comes from data shape, not the macro.
- **There was no data cache at all.** Returning to the Home tab meant 10 network requests; Library
  meant 3 + N folder requests; every tab switch added 2 more regardless of destination. The
  architectural fix is a single stale-while-revalidate store between service and views.
- **No image cache either.** `AsyncImage` at baseline 26 only has `URLCache.shared`, keeps no
  decoded bitmaps, and does no downsampling — 12 call sites, each re-decoding on every scroll-back.
- **A concrete quadratic bug**: pagination triggering used `items.firstIndex(of: item)` — a linear
  search with a **deep** synthesized `==` across a 63-stored-property model — called from every
  grid card's `.onAppear`. 100 cards → up to 10,000 full struct comparisons on the main thread
  during scroll. A one-line fix (`item.id == items.last?.id`).
- **A permanent full-screen `.ultraThickMaterial` sat under all of Home on tvOS** for an effect
  that wasn't even visible (the system background was already behind it) — pure wasted blur cost.
- **Response logging serialized every API response body to a `String` unconditionally**, including
  in Release builds — a full extra copy of every JSON payload in memory, every request.
- **No instrumentation existed at all** — no `os_signpost`, no perf tests — and critically, **tvOS
  has no MetricKit/Xcode-Organizer hitch-rate telemetry** (iOS/iPadOS/macOS/visionOS only), so the
  only measurement path is Instruments on real hardware plus a hand-rolled `CADisplayLink` sampler.
- **tvOS renders its UI into a 1920×1080 framebuffer even on a 4K Apple TV** — the system upscales
  the whole frame. Good news (blur cost is 2.07MP, not 8.3MP) and a hard ceiling for any
  downsample target (1920px on the long edge is the practical maximum for full-screen artwork).
- **Rivulet's on-device measurement is the calibration reference**: SwiftUI-Home vs. UIKit-Home on
  a real Apple TV 4K (3rd gen) — 1523ms vs. 530ms of hitch time in the first 5 seconds, 73.8MB vs.
  53.5MB RSS. Not a mandate to rewrite in UIKit, but their finding that "every blur/shadow/material/
  mask is a separate offscreen pass, and Apple TV's GPU can't clear enough of them per frame"
  applies directly.

## What was available at baseline 26

`@Observable`/`withObservationTracking`/`@ObservationIgnored` (17+) — invalidation on actually-read
properties in `body`, not on any change to the owning object; `@State`/`@Environment(T.self)`/
`@Bindable` as the corresponding property-wrapper replacements. `LazyVStack`/`LazyHStack`/
`LazyVGrid` (already in use). `containerRelativeFrame(count:spacing:)` +
`.scrollClipDisabled()` + `.scrollTargetLayout()` + `.scrollTargetBehavior(.viewAligned)` — the
canonical tvOS shelf recipe from Apple's own guidance, barely used at the time.
`onScrollVisibilityChange` (18+) for pausing offscreen work. `drawingGroup(opaque:colorMode:)` (13+)
— rasterizes a subtree to one bitmap so a blur is computed once, not every frame — already used in
two places but not the Home backdrop. `geometryGroup()` (17+) — isolates a subtree's geometry from a
parent's animation, unused. `layerEffect` (17+) — the app's variable blur, and the actual cost
center: uncached, recomputed on every composite.

New at 26: `backgroundExtensionEffect()` (Apple's own docs warn to "apply this modifier with
discretion… with consideration of visual clarity and **performance**"); `NavigationLink`s in lazy
containers collapsing to a single view instead of a list of views — a direct, free win for
`LazyHStack`/`LazyVGrid` full of `NavigationLink`s, i.e. exactly this app's card rows;
`buttonSizing(.flexible)`/`ControlSize`/`buttonBorderShape` removing `Spacer()`/
`frame(maxWidth: .infinity)` layout work from buttons; `GlassEffectContainer` batching multiple
glass surfaces into one render pass; the Instruments **SwiftUI template** (Update Groups, Long View
Body Updates, Cause & Effect Graph) as the primary tool for finding "expensive body" and
"unnecessary update" problems.

27-only: native `AsyncImage` HTTP caching + `asyncImageURLSession(_:)` (still not a decoded-bitmap
cache or a downsampler — a hand-written image pipeline stays useful even there); `@State` becoming a
macro that avoids repeated evaluation of initial-value expressions, back-deployed to 17 — directly
relevant to a specific risk noted below.

## What this became in the app

The quadratic `loadMoreContent` bug, the response-logging body serialization, the always-on Home
material, and the missing data/image caches are the direct ancestors of work now tracked in
[`01-foundation-continuity.md`](../../../ROADMAP.md) (`ContentStore`/
`RowSnapshotStore` shipped; a shared image pipeline is still listed as an open evaluation item
there — "evaluate Nuke vs. finish in-house," which mirrors this report's own build-vs-adopt
question). The hero-preview blur cost analysis here predates and matches the reasoning in
[`materials-blur-and-chrome.md`](../../../.claude/skills/apple-chrome/SKILL.md) for why
`variableBlur` stays private-API-and-isolated rather than a per-frame shader on a focus-driven hero.
Whether `@Observable` migration proceeded, and how far, is not something this archive can answer —
check current code.

## The offscreen-pass rule (the single most load-bearing finding)

Measured on a real Apple TV 4K (3rd gen) via Instruments' Animation Hitches template: 102 hitches
across 31 seconds (~once per 300ms), 1.25s of total stall, **average 63 offscreen passes per hitch,
maximum 99**. Instruments' own causal narrative named the mechanism: "potentially expensive render"
from **blur, shadow, mask, gradient, and translucent compositing** — each an independent offscreen
render pass the Apple TV's GPU cannot clear within a 16.67ms frame budget once enough of them stack
up. This app's inventory at the time: the progressive-blur hero (×2 call sites), a full-screen
`.ultraThickMaterial`, `.shadow` on several card/hero/season-rail elements, and a masked blur
fallback. **The rule that follows: zero extra effects per card.** `.buttonStyle(.borderless)` already
gives lift + specular + parallax in a system-owned layer; anything stacked on top adds to that cost
and, per a comment already in the codebase, can fragment the system effect itself. A key methodology
lesson from the same measurement: look at the `hitches` event table, not `hitches-renders` —
per-frame percentages ("only 3.1% of frames missed budget") badly understated the actual stutter
count (102 distinct freezes) that per-event counting revealed.

## The data-cache architecture (stale-while-revalidate)

The core shift: view models stop owning data and become read-only projections of one shared,
`@MainActor @Observable` store keyed by row identity (`RowKey` — continue-watching, a catalog
shortcut, watchlist, history, a bookmark folder), each entry carrying a TTL, hydrated **in `init`**
from a disk snapshot so a cold start paints yesterday's rows before the network responds. Reads are
synchronous from memory; `refreshIfStale` only issues requests for genuinely stale keys, deduplicated
via an in-flight task map so two screens wanting the same row never double-fetch. Pagination and
optimistic mutation (hide a card, mark watched) live on the same store. This is very close to what
shipped as `ContentStore`/`RowSnapshotStore` — check current code for the actual shape rather than
this report's sketch. Borrowed directly: silo-apple's `ResponseCache.swift` (`@MainActor`,
synchronous `get`/`set`, prefix-based family invalidation, a centralized `CacheKey` enum) and its
`HomeViewModel`'s `init`-time hydration plus its `isLoading`/`isRefreshing` distinction (spinner only
on first load, never over already-painted content, and errors never erase what's already drawn).

## The image pipeline (memory + disk + downsample + coalescing)

Three tiers: `NSCache` for decoded bitmaps (budget scaled by `ProcessInfo.physicalMemory` — halved
on constrained devices), disk cache of original bytes (not bitmaps — decode target size varies per
call site), and network fetch coalesced by URL so two rows showing the same title don't double-
download. Decoding goes straight to a target pixel size via
`CGImageSourceCreateThumbnailAtIndex` — the actual bottleneck on Apple TV is decode-to-full-size
followed by discard, not the network. Concrete budget math from this report: a 200×300pt poster on
tvOS (`scale == 1.0`) decoded to 400×600px RGBA is ~960KB; 120 on-screen posters ≈ 115MB if
undersized, ~65MB decoded to exact size; a full-screen backdrop is ~8.3MB each. Recommended
`NSCache.totalCostLimit`: 64–128MB depending on device memory, with a mandatory response to
`didReceiveMemoryWarningNotification` (drop decoded cache, keep disk) and a mandatory drop **before
player start** — posters aren't visible during playback and `AVPlayer` wants the memory.

Borrowed: Rivulet's `ImageCacheManager.swift` (the closest thing to a complete reference — memory +
disk LRU + stale-while-revalidate + coalescing + downsample + corrupt-byte validation + backoff
retry), whose own reasoning for its pixel ceilings ("the Apple TV renders into a 1080p framebuffer
and upscales the whole frame to 4K, so anything bigger than 3840px is decoded and thrown away") is
worth keeping even if this app's own ceilings should be tighter (it's supersampling for a use case
this app doesn't need). Not borrowed: Nuke/NukeUI (silo-apple's approach) — an added dependency this
app's small-dependency stance argues against, though its device-memory-budget numbers and
`trimDecodedMemory()`-before-player pattern were worth keeping as reference values.

## `@Observable`: yes, but not for its own sake

Apple's own framing: "SwiftUI updates views based on changes to observable properties that a view's
`body` reads, rather than any property changes to an observable object." At the time, this app had
20 `ObservableObject` classes and 66 `@Published` properties, where any single field change on a
catalog object invalidated every view watching that object — a `publish()` called N times for N
bookmark folders meant N full screen re-evaluations. The one genuinely nontrivial part of migrating
is Combine: three `.debounce`-based search/filter chains and several `$authState.userState.filter`
chains all have straightforward `.task(id:)`-based replacements (task cancellation gives debounce
and cancellation for free — Combine isn't needed for that pattern at all).

One risk worth flagging even now: swapping `@StateObject` for `@State` changes initialization
semantics — `StateObject.init(wrappedValue:)` takes an autoclosure (evaluated once, lazily);
`State.init(wrappedValue:)` does not, so a view-model constructor moved naively into a `@State`
default would run on every `init` of the containing view and get discarded. The fix is either
building the model lazily inside `.task` rather than at property-declaration time, or (better)
moving away from per-view models toward the shared store above, which sidesteps the question
entirely. This is exactly the trap the app's existing `@autoclosure @escaping` initializer
convention (`init(model: @autoclosure @escaping () -> X)`) works around for `@StateObject` today —
any `@Observable` migration has to either replicate that laziness deliberately or restructure around
the shared-store pattern instead.

## tvOS memory, GPU, and 4K specifics

tvOS renders its UI into a 1920×1080 buffer even on 4K hardware (`UIScreen.main.scale == 1.0` on a
real device; the simulator reports `scale == 2.0`, another reason not to trust simulator perf
numbers) — the system does the upscale. Practical ceiling for any full-screen artwork target:
1920px on the long edge. No documented per-app memory limit exists; jetsam kills under pressure.
Reference points: silo-apple treats a device as "constrained" at
`physicalMemory <= 3.5GB` and halves its decoded-image budget there; Rivulet's on-device Home screen
held 53–74MB RSS. Practical target this report set: keep the Home screen's RSS under 150MB, with a
64–128MB decoded-image cache budget scaled to device memory.

## How to measure (since tvOS field telemetry doesn't exist)

Five metrics, all requiring **real hardware**, none of them meaningfully automatable in CI: hitch
time ratio while holding a directional key across a long row (Instruments' Animation Hitches
template, exported and parsed for event count + offscreen-passes-per-hitch, not the misleading
per-frame percentage); focus-move latency (Points of Interest interval from key-press to rendered
new state, target <100ms, watching specifically for *overlapping* intervals — the crossfade-pileup
symptom); network cost of returning to a tab (count HTTP requests across a Home→Search→Home→
Library→Home cycle, target 0 within TTL); RSS growth across a multi-tab traversal loop (target
<150MB steady-state, <10MB growth per loop — a growing baseline means the image cache isn't
releasing memory); and the SwiftUI Instruments template's Long View Body Updates + Cause & Effect
Graph, watching for how many view updates a single focus move triggers (the report's proposed test
of whether `@Observable` restructuring actually worked: one arrow in the graph per focus move, not
120).

What *is* CI-automatable and cheap: a network-request-count unit test against a service spy
("second Home appearance within TTL makes zero requests" — directly catches a data-cache
regression); `XCTMemoryMetric`/`XCTClockMetric` with generous thresholds to catch catastrophic
regressions (a 500-element `loadMoreContent` test would have caught the quadratic bug above); and a
CI grep-gate banning specific modifiers (`.ultraThickMaterial`, `layerEffect`, `.shadow(`) inside the
card-rendering package — cheap, boring, and effective, modeled on Rivulet's SwiftLint rule banning
`UIHostingController` in a cell.

## Open questions this report left unverified

Actual pixel dimensions of kino.pub's poster URLs (determines real downsample targets and memory
savings — checkable with `curl -sI` plus `CGImageSourceCopyPropertiesAtIndex`); the real on-device
cost of decoding this app's specific `MediaItem` model (the "4478ms to decode 116 full-graph items"
number is from a different app's model, not measured here); whether `CIFilter.maskedVariableBlur()`
is actually available on tvOS 26; RAM capacity of the 3rd-generation Apple TV 4K (public sources
didn't confirm a number); and whether `LibraryCatalog` has the same quadratic pagination bug found in
`MediaCatalog` — flagged as needing the same grep, not separately checked here.
