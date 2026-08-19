# KinoPub Apple Client — agent context

A native client for kino.pub, shipped as **one multiplatform target** on tvOS, iOS, iPadOS and
macOS. tvOS sets the media / focus / 10-foot bar; the other platforms get their own native controls,
not TV chrome forced sideways.

**The renderer is not the same on every platform, on purpose.** SwiftUI is the default on iOS,
iPadOS and macOS, including system navigation transitions. **On tvOS, media surfaces are UIKit +
TVUIKit** — collection views, the three system cells, the focus engine. When you find SwiftUI
driving a heavy tvOS surface, treat it as a leftover to port, not a base to build on: rails, grids
and cells are already decided, and a substantial addition to one of them is the signal to move it.

Shared across platforms: models, services, view models, component *semantics*, focus priority,
design tokens, assets. **Not shared: view hierarchy, geometry, point values.** Two renderers for one
semantic component is not a DRY violation; two components for one idea on one platform is a defect.

## Quick reference

- **Platforms:** tvOS · iOS · iPadOS · macOS, deployment floor **26.0**, one target
  `KinoPubAppleClient` (product `KinoPub`). Mark 27-only API explicitly.
- **Language:** Swift 5 mode in packages (`swift-tools-version: 6.2`).
- **UI:** SwiftUI everywhere except tvOS media surfaces (UIKit + TVUIKit). See above.
- **Player:** native `AVPlayerViewController` / `AVPlayerView`, one app-scoped `PlaybackSession`.
  No custom transport chrome, ever.
- **Appearance:** dark only, forced on every platform, until the deliberate light-theme stage.
- **Distribution:** personal builds / TestFlight. App Store review is not a target — which is what
  makes isolated private API acceptable.
- **Our docs are English-only** — but a vendor's own documentation is kept **verbatim, in its
  language** (`docs/providers/kinopub/` is Russian). Do not translate or delete it; it has been
  deleted once already. UI strings are RU + EN through `Localizable.xcstrings`.
- **Repo layout:** `KinoPubAppleClient/` (app), `Packages/KinoPub{UI,Backend,Kit,Metadata,Logging}/`,
  `workers/` (Cloudflare), `tools/` (offline crawlers/probes).
- **Third-party SPM:** `KeychainAccess`, `PopupView`, `Reachability`, `Nuke` (artwork),
  `Pulse` (network log). Allowed — see [Dependencies](#dependencies).

### Where to read more

| Need | Load |
| --- | --- |
| tvOS cells, rails, focus engine, on-device verification | skill `tvos-surface` |
| Glass, materials, blur, tabs, search, navigation, layout containers | skill `apple-chrome` |
| AVKit surfaces, subtitles, playback routing | skill `player-avkit` |
| Metadata aggregator, providers, enrichment | skill `metadata-service` |
| Where a new fact or decision belongs | skill `docs-upkeep` |
| What we are building next | [ROADMAP.md](ROADMAP.md) |
| What the product *does* — decided behavior, per feature | [docs/product/](docs/product/) |
| Provider capability sheets | [docs/providers/](docs/providers/) |
| Community fork rules | [docs/community-fork.md](docs/community-fork.md) |
| Dated history — evidence, never law | [docs/archive/](docs/archive/) |

## Authority

1. The user's explicit decision in the current conversation.
2. This file.
3. [ROADMAP.md](ROADMAP.md) — accepted behavior and what is next.
4. Skills — how to do a specific kind of work.
5. `docs/archive/` — evidence. **Never automatic requirements.**

If sources conflict, stop only the disputed part and ask. Do not invent blockers, do not close open
design questions with "Apple defaults", and do not rewrite docs to rationalize an implementation.

**Preserve user work.** Every pre-existing modified or untracked file is user-owned. Re-read a file
immediately before patching it. Prefer narrow patches; do not revert, wholesale-replace or reformat
unrelated work.

## Constraints are not requirements

A workaround you found while implementing is **not** a product rule until the user says it is. This
is the single failure that produced most of what had to be deleted from this repo's own docs:

```
SwiftUI (or our use of it) can't do X → agent works around it → workaround gets written down
as "how the page works" → next agent reads it as law → builds the next thing to defend it
```

Label every limitation, where you record it:

| Label | Needs to be believed | Expires |
| --- | --- | --- |
| **Apple API limitation** | The symbol named, from SDK headers, plus what you tried | Next SDK — re-probe, don't inherit |
| **Performance limitation** | A number, from a device or Instruments | Next measurement |
| **Focus / navigation invariant** | A state the user can get stuck in | Never — it is about the user |
| **Product decision** | The user said so | When the user says otherwise |

**Only the last two may become durable requirements.** The first two become an **adapter**: one
named place with the limitation in its doc comment. An adapter is never a statement about what the
product is, and never an argument for a second component.

Probe before claiming an API limitation. `swiftc -typecheck` against the SDK settles most of them in
a minute; guessing from a header name has cost days here.

### 🔴 Banned patterns — do not reintroduce

Each is us re-implementing something Apple owns, worse. If a task seems to need one, the design is
wrong one level up — stop and ask.

| Banned | Cost when we did it | Instead |
| --- | --- | --- |
| A focus-routing layer of our own (`focusBridge`-shaped) | We do not own the focus engine; UIKit does, and it is spatial | `.focusSection()`, `defaultFocus`, `indexPathForPreferredFocusedView(in:)` |
| One `@FocusState` case bound by several sibling views | Six hero buttons shared `heroOther`: focus froze dead on Play, Right and Down both no-ops, **and Menu quit the app** instead of popping — the confused focus state broke the NavigationStack back-context too. Cost a misdiagnosed revert of an unrelated change | One case per focusable view, or no `@FocusState` |
| Manual focus delays — `asyncAfter`, same-press guards | Racing the engine's own animator; the race returns on a different box | React to where focus landed |
| Hand-rolled focus chrome — `scaleEffect` / `brightness` / shadow / parallax on focus | Verdict was "не выглядит нативно", and it was right | `.buttonStyle(.card)` on tvOS; system cells; `.borderless` + `.hoverEffect` only where the label *is* an image |
| Continuous scroll-progress choreography (`washProgress`, "at 0.37 move the artwork") | Keyed the blur to incidental content geometry, so it "only worked for series"; re-ran the whole page body — every shelf, every `updateUIViewController` — on every scroll frame | Discrete state: hero owns focus, or it does not |
| Hand-driven scrolling (`isScrollEnabled = false` + `CADisplayLink` on `contentOffset`) | Replacing the focus engine's scroll animator to win a fight we started | Let focus scroll the page; if the landing is wrong, fix layout or use a collection view |
| A custom hero focus graph (hero as a detached layer with its own rules) | Broke directional continuity *and* the responder chain | One connected focus graph |
| A SwiftUI state machine around preview / trailer playback | The reference app's least attractive code, and ours was worse | UIKit, if it is ever built |
| **Screen-specific component variants** | The most violated rule in this repo's history | One component, configured |

### ❌ Invalid — agent-invented, never requirements

- **"The tab bar must stay pinned through scroll."** No product requirement, and no tvOS API
  (`.tabBarMinimizeBehavior(.never)` is iOS 26+, unavailable on tvOS/macOS). The bar is a temporary
  shape; take what the system `TabView` does.
- **"`TVMediaItemContentConfiguration` can't show an icon, so we need our own badge overlay."**
  `badgeText` is a `String`, and an SF Symbol is a character in the SF Symbols font (custom symbol,
  asset, or a letter after that). The overlay may earn its place for real reasons — it pairs the
  badge with a scrim, checkmark and progress bar, which move together — but state *that*.
- **Cross-platform geometry parity.** "iOS shows two lines under a poster, so tvOS must too" is a
  reflex, not a requirement. The two-line tvOS caption cost tile width and rendered nothing.
- **"The hero must live outside the scrolling container."** Described one broken attempt. What is
  outside the scroll is the *artwork layer*.
- **A compact title / floating header logo.** Dropped 2026-08-13 unless navigation chrome needs one.

### ✅ Accepted adapters

Allowed to exist, one place each, limitation in the doc comment:

- **`TVUIKitMediaItemMetrics`** — `orthogonalLayoutSectionForMediaItems()` exposes neither its group
  nor its item, so it cannot be resized. We measure what it produces per width and rebuild an
  equivalent section at our scale; Apple keeps owning the proportions.
- **The progress bar in the media-item overlay** — `configuration.playbackProgress` only paints on
  the *focused* tile, and "started, not finished" is what an idle rail has to say.
- **`NetworkConsoleView`'s macOS branch** — `PulseUI.ConsoleView` does not exist on macOS in Pulse
  5.2.3 (the module ships `ConsoleView-ios/-tvos/-watchos`, and its public init is fenced
  `#if !os(macOS)`). Capture still runs there, so the Mac gets export-to-`.pulse`, and streaming to
  the Pulse app is the live reader. Re-probe on the next Pulse major.
- **Auto-connect in `setRemoteLoggingEnabled`** — Pulse keeps `RemoteLoggerSettingsView` internal,
  so there is no server picker to present. "First server found, then remembered" is the only
  selection model its public API offers. Re-probe if that view goes public.

An adapter that stops being needed gets deleted, not kept "in case".

## Focus (tvOS)

**The focus engine is Apple's. We do not build a layer on top of it.**

- Interactive controls are reachable and visibly focusable. `.buttonStyle(.plain)` commonly kills
  visible focus — verify before using it.
- **For a focusable container, reach for `.buttonStyle(.card)` and write no focus code at all.**
  Apple's `DestinationVideo` sample does `#if os(tvOS) .card #else .plain #endif` on every card,
  applies it once to the enclosing stack, and fences `.hoverEffect()` to iOS/visionOS. Everything
  focusable there is a `Button` or `NavigationLink`, including pure focus stops.
- **`.hoverEffect(.highlight)` is for controls whose label *is* the image.** The system highlight
  attaches to the first `Image` in a label, so on `icon + text` (rating tiles, vote pills) it scales
  and shadows the icon alone while the container sits still. Learned twice in one day.
- **Never bind two sibling views to the same `@FocusState` equals-value.** See the banned table.
- **Every state keeps a focus escape path.** A dead end on tvOS is unrecoverable — the remote has
  nowhere else to go:
  1. Do not enter a "scrolled past the hero" state until at least one focusable row exists below.
  2. Do not drop the hero's focusability until focus has actually landed below it. Fading chrome is
     not removing it — the 0.35 opacity floor exists so Play/More stay in the focus graph.
  3. Empty and error states are **focusable sections with a Retry control**, never an empty list.
- No inert reserved space above the first focusable row — it steals Up and traps focus in the tab bar.
- **A known-bad focus pattern sitting in a checklist as a "someday" item is a bug to fix on sight.**
  One of those cost a whole misdiagnosed detour before anyone traced it.

Details, cells and traps: skill `tvos-surface`.

## Components

**Pages are assembled from a fixed catalogue. A page is a list of typed sections, not a
hand-written stack of views.** Two pages showing a shelf show the *same* shelf — same component,
same metrics, same focus behavior. When it is wrong, it is wrong in one place.

🔴 **No screen-specific variants.** A component that differs only because a different screen uses it
is an architecture defect:

```
allowed                          never
MediaCard                        HomeMediaCard
  configuration:                 DetailMediaCard
    kind / metadata /            SearchMediaCard
    presentation
```

Different **platforms** may render one semantic component differently. Different **screens** may not.
While a look is unsettled it is fine to keep 2–4 variants *of one component* behind a switch, in one
file, and delete the losers with the switch.

- Reusable UI lives in `KinoPubUI`; screen-specific composition stays in the app target.
- Semantic tokens only — `Color.KinoPub.*`, `TypeScale`. `Color.KinoPub.background` is **opaque** on
  every platform: a transparent token no-ops every `.background(…)` and every derived scrim. Layer a
  scrim explicitly instead.
- **Always a Dynamic Type text style, never `.system(size:)`.** Vary weight and colour, not size by
  hand. tvOS 27 turns on Dynamic Type system-wide, and hard-coded sizes are the named cause of
  breakage. `.system(size:)` survives only where a glyph lines up with fixed geometry.
- One running-text size per page family (`TypeScale.detailBody` for the item page). When unifying
  sizes, unify **up** on the style the content deserves.
- Ship a working `#Preview`, on tvOS too when the component is focusable. Previews do not prove
  focus.
- **On tvOS there are three cells and one collection** — person, wide 16:9, poster — all from
  TVUIKit, in one `UICollectionView` per page region. A hand-assembled tile is a defect even when it
  looks right. Full standard: skill `tvos-surface`.

## The detail page

- **The artwork layer sits behind the scroll** — parallax, blur and crop live there, and nothing
  focuses it. **The hero's own content scrolls with the page**, in one connected focus and view
  graph with the sections below. Splitting them into independent scroll/focus worlds broke
  directional continuity and the responder chain.
- **Two discrete states, not a scrub.** The hero either owns focus or it does not; that flag is
  derived from focus, never from scroll offset, and has exactly **one writer**. Two writers racing
  one page-wide flag has broken this page twice.
- **Lead with what can be played.** The cheapest path on a remote is `hero button → playable rail →
  everything else`. Episodes, parts, versions and trailers are one rail directly under the hero;
  related titles, ratings, cast and info follow. Ordering is by what the user can do now, not by
  entity type — a movie is not "the layout with the rail missing".
- **One playable rail, not one section per content type.** Episode, trailer, part, version and extra
  share a shape (id, title, duration, image, source, progress, kind) and differ in one field, so
  they share a component. A trailer tile *is* an episode tile *is* a Continue Watching tile.
- Versions of one film (`subtype: multi`) are `PlaybackVariant`, never episodes — one rail each,
  never mixed. Why, and what the payload actually looks like: `PlaybackVariant.swift` and
  [docs/providers/kinopub/video.md](docs/providers/kinopub/video.md).
- **No compact title, no floating header logo** unless navigation chrome requires one.
- Sections are data (kind + payload), empty ones simply absent, order defined in one place.
- "Related" renders through the same shelf component Home uses.
- 🔴 **A rule that depends on a title's type or genre lives in `MediaPresentationProfile`, never as
  an `if type == …` in a view** — written into one view it lands on the detail page and is missed on
  the poster, the card and the label beside it. *What* each kind shows is product, not architecture:
  [docs/product/media-presentation.md](docs/product/media-presentation.md).

## Chrome

- **Dark only**, forced, until the light-theme stage. tvOS ships no semantic background colour
  (`systemBackground` is iOS-only), so the TV base is real black.
- **All `glassEffect` goes through `kinoGlass` / `kinoGlassGroup`** (`KinoPubUI/DesignSystem/`),
  never the raw API at a call site — the helper degrades to an opaque fill under Reduce Transparency
  / Increase Contrast. `.buttonStyle(.glass)` / `.glassProminent` are a separate, fully system-owned
  path and deliberately do not route through it.
- **Glass samples the content behind it.** A flat page fill gives it nothing and degrades it to a
  matte slab — never rely on the page fill to feed glass.
- **The navigation bar is left to the system.** Do not stack a material behind the page to "help" it.
- **No page-level material behind Home.** `backgroundExtensionEffect` as shell chrome is **banned**
  (sidebars displace content — there is nothing to bleed under).
- Blur: private `CAFilter` `variableBlur` over **static** art only. **No blur over video on
  tvOS/macOS**; blur over video is fine on iOS/iPadOS.
- Hero CTAs are a white Play pill + translucent circular secondaries — not glass.
- **Tab bar:** system `TabView` on tvOS and macOS, adaptive on iPad. No pinning requirement, no
  `.toolbar(.hidden, for: .tabBar)`, no custom bar layered over content.
- No shadows on tvOS cards / badges / action buttons.

Details: skill `apple-chrome`.

## Data and continuity

- **Watch state is `WatchProgress`.** Fraction, unwatched / inProgress / finished, and
  the credits window (8% of runtime, 60–180 s, capped at half) live in that one type.
  `Episode` / `Video`.isWatched is the server flag *or* `isFinished`. A card paints
  `resumeFraction`, never a 0.95 / 0.02 of its own — five percent leftover on a two-hour
  title is six minutes, the classifier's window is three. Skip / outro markers, when they
  land, feed this type; they do not grow a second threshold.
- **Continuity beats placeholders.** Stale local data and already-loaded artwork beat blank screens.
  Card → detail carries the known item, artwork handle and palette; detail paints from that snapshot
  and enriches — it must not blank-reload what the card already had. Exact-layout skeletons only on
  true cold loads, and only when the geometry matches what arrives.
- Deduplicate in-flight work; stale paints first, revalidation runs underneath. Never reuse eternal
  grey as both loading and failure.
- **One store ownership model.** `ContentStore` owns Home/Library *rows*; `MediaLibraryStore`
  owns per-item optimistic library state (watchlist / watched / votes, plus a download
  façade); `Artwork` owns remote images; `MetadataCache` (when it lands) owns item-facts.
  Do not invent a fifth cache beside those. Bookmarks stay on `BookmarkMembershipStore` /
  `BookmarkFoldersStore` — the library store does not replace them. **All remote images go
  through `Artwork`** — one decoded memory
  cache keyed by target size, one disk entry per URL, coalescing and prefetch, on every platform.
  Use `CachedRemoteImage`, or `ArtworkImage` when the states need different geometry. `AsyncImage`
  is a regression and no longer appears anywhere in this repo. Local optimistic writes (hide, watched, bookmark) are
  authoritative until the server contradicts them.
- **Bookmarks are answered locally.** `BookmarkMembershipStore` (item → folder ids) and
  `BookmarkFoldersStore` (the folder list, persisted across launches) draw every bookmark control.
  `GET /v1/bookmarks` belongs to the screens that list folders — Library, Bookmarks, the sidebar,
  which hand their result back with `adopt(_:)` — and to the moment a folder is created or deleted.
  **A detail page fetches neither**: membership is already on the item payload (`bookmarks`), and
  `get-item-folders` is gone on purpose.
- **`nolinks=1` on a series detail page is off** (`FeatureFlags.seriesDetailsWithoutLinks`).
  It is built and switchable — `MediaItemModel` asks without links when it knows the card is
  episodic (`isEpisodicType`), and `MediaLinksResolver` fills one `Episode` from
  `/v1/items/media-links?mid=` when it is played — and kino.pub will make it the default, so
  it is what we flip then. **A `nolinks` payload still lists `files`, with no link bag under
  any key**: never assume a file carries a URL, ask `hasPlayableURL` (requiring one failed
  every series page with `keyNotFound 'urls'`). Films always come with links.
- tvOS purges `Caches/` when the app is not running — lean on longer in-memory TTLs, don't fight it,
  and don't pretend offline parity exists.
- **New API calls go through `KinoPubBackend`** — Endpoint + model + service protocol + mock.
- **Document an external source before integrating or extending it** — every method, field and
  model, including ones we do not want, into a sheet in `docs/providers/` *first*. Store every
  detail the API gives; decide what is redundant later, from evidence.
- **New providers land server-side, not in the app.** The app gets one more field, not one more
  network client, and never models a provider's response shape. Skill `metadata-service`.
- **Telemetry:** no third-party SDK. TestFlight / Xcode Organizer already deliver crashes. Do not
  add Firebase, Sentry or similar without an explicit decision. **This is a rule about *sending*
  data somewhere.** On-device diagnostics that leave nothing behind — `Pulse`'s local store behind
  `NetworkDiagnostics` — are not telemetry and are not covered by it.
- **Diagnostics are shipped, not DEBUG-only.** The launches worth reading a log for happen on a
  physical Apple TV running TestFlight, with no Xcode attached, so Settings › Diagnostics › Network
  log is in every build. Capture goes through `NetworkDiagnostics.start()` once at launch (it
  swizzles `URLSession`, so it catches every client and shows tasks still in flight). Tokens are
  redacted **at capture**, because the store is exported and shared.
- **The log records API traffic only.** Artwork and media are excluded by host *and* extension,
  and `NetworkDiagnostics.store` is ours rather than `LoggerStore.shared` because Pulse's defaults
  — 256 MB of store, 8 MB per body — are what produced 50 MB log files. Ours: 32 MB store, 512 KB
  per body, in `Caches/`. Adding a media host to the app means adding it to `excludedHosts`.
- **"What are we waiting for" is `NetworkActivity`** (`KinoPubLogging`), hooked once in
  `URLSessionImpl` so no call site has to remember to report. Pulse logs completed tasks; this is
  the live one. It feeds two readers: the debug overlay, and **`LaunchStatusLabel`, which ships** —
  the launch splash names what is outstanding ("Проверяем сессию · Загружаем историю") instead of
  showing a bare spinner. Entries carry a **localization key**, never a path: a raw `/v1/items/…`
  on a user's TV is worse than saying less, so an unmapped endpoint reads "Загружаем" and keeps the
  path for the overlay only. Add a key to `Localizable.xcstrings` (RU + EN) when you add an endpoint
  family, not a string at the call site.
- **Downloads are non-TV only.** Feature-gate incomplete surfaces (`FeatureFlags`) rather than
  inventing half-UI. An off flag must skip the work — network, sampling — not only hide UI.

## What is dead — do not revive

If you find a comment or a doc referencing these, it is stale.

- `washProgress` / `onScrollGeometryChange` scroll scrub, `MediaItemHeroScrollDriver`,
  `HeroMaterialBackdropView`, the `ZStack` hero-outside-scroll structure, the overlay title logo.
- `focusBridge`-style routing, `SiriRemoteTilt` / Game Controller fake parallax,
  `ExpandableButtonStyle`, `ExpandableLabel`, `RatingTileButtonStyle`, `DetailTileFocusChrome`.
- `MediaItemDetailSheet` / `MediaItemSheetLayout` — replaced by `InfoPopup`, where **the clipped
  content itself is the trigger**, never an `i` button beside it.
- `TVUIKitContinueWatchingCell` as a landscape grid tile — the grid dequeues the same media-item
  cell the rails use.
- Netflix-style Home focus-preview (`showsFeaturedPreview`) and the 560pt reserved spacer.
- Metal `ProgressiveBlur`, page-level `.background(.ultraThickMaterial)`, hand-rolled Button-row
  sidebars, custom `ultraThickMaterial` toolbars.
- The tvOS poster experiment: pinning `TVPosterView.contentSize` + `scaleAspectFill` +
  `clipsToBounds`. Aspect-fill crops 2:3 art, and **clipping the image view kills the parallax** —
  the lockup moves content inside its own frame. Not obvious from the API; do not retry blind.
- `PlexDataStore`-style optimistic Continue Watching mutation from a shelf.
- The hand-rolled artwork cache: `TVUIKitRemoteImage`'s private `NSCache`, the `ArtworkFetcher`
  coalescing actor, `preparingThumbnail` downsampling, and `AsyncImage` in `CachedRemoteImage`.
  All four behaviours survive — `Artwork` provides them, on four platforms instead of one.

Known bad, still present, do not polish: `HudToast` (rewrite, don't patch).

## Build, run, verify

```bash
# tvOS simulator build
xcodebuild -scheme KinoPubAppleClient -destination 'platform=tvOS Simulator,name=Apple TV' build
```

- **There is no Simulator.app on current Xcode.** The simulator window is hosted by **Device Hub**
  (`com.apple.dt.Devices`). Focus its title bar; arrow keys + Return are the D-pad. **Escape is not
  Menu** — use the on-screen remote's `‹` button. `simctl` has no directional-press API.
- **Focus bugs do not show in previews**, and a static screenshot cannot show animation smoothness.
  Say "not verified on device" rather than implying it was.
- **Shared debug session:** every DEBUG build mirrors the kino.pub session to
  `~/.kinopub-dev-session.json` and reseeds the Keychain from it, so a reinstall or a platform
  switch does not need a fresh activation code (`DevSessionMirror`). The account has five device
  slots — do not spend them on the dev loop. Sign-out deletes the file on purpose.
  The sandboxed macOS Debug build needs its own entitlements file for that path; **Release must keep
  pointing at `KinoPubAppleClient.entitlements`** — temporary exceptions fail review. In
  `project.pbxproj` a configuration's `name = Debug` line comes **after** its settings; verify with
  `codesign -d --entitlements - --xml <app>` rather than trusting the edit.

### Verification by risk

| Risk | Examples | Required before "done" |
| --- | --- | --- |
| Low | Copy, localization keys, label → existing symbol | Diff review |
| Medium | New reusable view, layout tweak, model mapping | `#Preview` / focused package build |
| High | Navigation, focus, materials, player, cache/session lifetime, private API | Build affected platforms + visual or remote check, or say `validation pending` |

Deferred verification is allowed. Silent "everything landed" claims are not.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Focus frozen on one control; Right/Down no-ops; Menu quits the app | Two sibling views share a `@FocusState` case |
| Up from a section jumps to the tab bar or fails | The hero band has no full-width `.focusSection()` |
| Only the icon inside a button scales, and gains a shadow | `.hoverEffect(.highlight)` on an `icon + text` label — use `.card` |
| Posters stranded enlarged, parallax-wiggling while unfocused | The system's coordinated unfocus animation never ran; several sibling collections in one page region is the suspect shape |
| A tile repaints blank after recycling | The cell skipped the synchronous `TVUIKitRemoteImage.cached(url:size:)` probe, or asked at a size no cell decodes at — a byte cache does not help, decoded ones are keyed by size |
| Blur/choreography "only works for series" | Something is keyed to incidental content geometry instead of state |
| The page moves a little, then stops; background changes but layout doesn't | A threshold copied from a swipe-driven Apple sample onto a focus-driven page |
| macOS: sidebar and player on screen together | A play entry point used `NavigationLink` instead of `PlayerLink` |
| tvOS launch is slow with an empty loader | Nothing is stored; the launch blocks on the whole session instead of painting cached rows. Read Settings › Diagnostics › Network log, and switch on the in-flight overlay — do not guess from a spinner |
| "What did the server actually reply?" | Settings › Diagnostics › Network log — full bodies, headers, timing. The one-line `ResponseLoggingPlugin` never had the body |

**Standing lesson:** copy a sample's *mechanism*, re-derive its *constants*. Two passes in a row
went wrong by porting thresholds tuned for a swipe-driven page onto a focus-driven one.

## Key files

| Purpose | File |
| --- | --- |
| Feature flags | `KinoPubAppleClient/Services/Configuration/FeatureFlags.swift` |
| Shelf / card sizing | `Packages/KinoPubUI/Sources/KinoPubUI/Layout/ShelfMetrics.swift` |
| Type scale | `Packages/KinoPubUI/Sources/KinoPubUI/Layout/TypeScale.swift` |
| Glass helper | `Packages/KinoPubUI/Sources/KinoPubUI/DesignSystem/KinoGlass.swift` |
| tvOS cells / rails / collection | `Packages/KinoPubUI/Sources/KinoPubUI/Components/TVUIKit/` |
| Artwork cache (the only place Nuke is imported) | `Packages/KinoPubUI/Sources/KinoPubUI/Components/Content/ArtworkPipeline.swift` |
| Home/Library rows | `KinoPubAppleClient/Services/Cache/ContentStore.swift` |
| Per-item optimistic library | `KinoPubAppleClient/Services/MediaLibrary/MediaLibraryStore.swift` |
| Network log (the only place Pulse is imported) | `Packages/KinoPubUI/Sources/KinoPubUI/Diagnostics/NetworkDiagnostics.swift` |
| In-flight activity registry | `Packages/KinoPubLogging/Sources/KinoPubLogging/NetworkActivity.swift` |
| Expanding clipped content | `Packages/KinoPubUI/Sources/KinoPubUI/Components/InfoPopup*` |
| Detail page | `KinoPubAppleClient/Views/MediaItem/` |
| Routes / destinations | `KinoPubAppleClient/States/Navigation/` |
| Player | `KinoPubAppleClient/Views/Player/PlayerManager.swift` |
| API client | `Packages/KinoPubBackend/Sources/KinoPubBackend/` |
| Metadata enrichment | `Packages/KinoPubMetadata/` |
| Session mirroring | `KinoPubAppleClient/Services/AccessToken/AccessTokenServiceImpl.swift` |

## Working agreement

1. **Model before layout.** What is the thing the user acts on, and what can they do with it right
   now? A page growing per-type sections is usually a data question answered in the view layer.
2. **Capability and data flow first** — what changes in services / models / stores, what old path is
   removed or merged.
3. **Ask which system primitive Apple provides** before asking how to reproduce a look. Then:
   system control of that platform's renderer → system API through a thin bridge → a proven pattern
   from a reference app or mature library → minimal custom. Custom needs the missing API named,
   alternatives rejected, and the ongoing cost stated.
4. **Borrow before build.** Apple public API → existing atoms in `KinoPubUI` → reference apps and
   the `community` remote (backend slices only) → a mature library → new in-house code. See
   [Dependencies](#dependencies).
5. **Ambiguous visible UI gets 2–3 genuinely different, fully interactive variants** in
   `KinoPubUI/Previews/` behind `#if DEBUG`, on a named axis; promote one and delete the file.
   Predetermined system controls do not get variant theatre.
6. **One reviewable slice.** Do not touch unrelated dirty files.
7. **Verify by risk** (table above), and be honest when verification is deferred.
8. **Record what you learned where it belongs** — skill `docs-upkeep`. Tick the ROADMAP line;
   append genuinely notable facts to `CHANGELOG.md`. README changes only for public positioning or
   a macro stage.

### Dependencies

**A third-party package is not a failure state, and nothing here bans one.** The
one-component-per-idea and no-custom-chrome rules are about *our UI*; they say nothing about SPM.
Read them as a dependency ban and you get the artwork split: tvOS had a hand-written decoded-image
cache with size keys, a coalescing actor and a prefetcher, iOS/macOS had `AsyncImage` and none of
it, and a fix on one side never reached the other. One package deleted both.

Take one when it replaces code we would otherwise own and get wrong — not because the API is nicer,
and never because a list of cool repos exists. Then:

- **It stays behind our own type. No call site imports it.** `Artwork` / `CachedRemoteImage` /
  `TVUIKitRemoteImage` are the only things that know Nuke exists, so replacing it is one file.
- Pinned to a major (`from:`), and it must build on **all four platforms** before "done".
- Declared in the package that needs it, not the app target, unless the app is its only user.
- Exception: **telemetry** — see [Data and continuity](#data-and-continuity).

### Style

- 2-space indentation.
- SwiftUI view models: `@StateObject` via `@autoclosure @escaping` initializers, matching `Views/`.
  `@Observable` migration is type-by-type; `State.init(wrappedValue:)` has **no** autoclosure
  overload, so a naive `@StateObject` → `@State` swap re-creates the model on every view `init`.
- Services: protocol + `…Impl` + `…Mock`. View models: `ObservableObject`, `@MainActor` when
  touching UI.

### Anti-patterns seen here

- Inventing design-decision blockers the user did not set.
- Promoting a workaround to a requirement (see above — this is the big one).
- Encoding agent assumptions into docs, then treating them as law.
- Claiming an API limitation without a probe.
- Marking work complete after a tvOS-only compile while macOS is broken.
- Overwriting the user's blur / glass / banner / badge decisions.
- Treating one stream survey as a global ban on capability badges the user still wants.

### Community fork

[dungeon-master-xx/kinopub-apple-client](https://github.com/dungeon-master-xx/kinopub-apple-client)
is tracked as remote `community`. **Steal Request / Model / Service slices only; never rebase our UI
onto theirs.** Reference apps (Rivulet, Silo) are technique-only — PolyForm Noncommercial, never
code. Details: [docs/community-fork.md](docs/community-fork.md).
