# Plan: UI modernization on the 26.0 baseline

> **Archived 2026-08-13.** Already closed to history before the move. Kept for the file:line
> rationale behind changes that landed; every open item went to ROADMAP long ago.


> **Dated implementation history — not living authority.** Current rules:
> [AGENTS.md](../../../AGENTS.md), [policies](../../../AGENTS.md), [features](../../../ROADMAP.md),
> [apple-platform](../../../.claude/skills/). Open work lives in feature docs (especially
> [01-foundation](../../../ROADMAP.md)). English knowledge base:
> [skills](../../../.claude/skills/). Russian snapshot:
> [docs/archive/research-2026-07/](../research-2026-07/).

Date: 2026-07-28. Historical status notes below; verify against feature docs before treating items as current.

## Closed to history — where the open work went

This plan no longer carries unchecked boxes. Everything still to do was moved into feature-doc
checklists; `- [x]` entries stay as a record of what landed, and the prose under each moved item
stays here as the detailed rationale / file:line evidence.

| Moved work | Now tracked in |
| --- | --- |
| Atoms, duplication, accessibility, type scale, focus / navigation / chrome cleanups | [01 — Foundation](../../../ROADMAP.md) |
| Resume bugs, Skip Intro, subtitle rendering correctness, player perf and lifetime | [07 — Playback conveniences](../../../ROADMAP.md) |
| Tap-a-word word-chip focus | [08 — Advanced subtitles](../../../ROADMAP.md) |

Do not re-open boxes here. Add work to the feature doc that owns it.

## Where we actually are (verified 2026-07-28, updated after Phase 3 Home banner)

Phase 0–2 are in. Packages sit on `.v26` with `swift-tools-version: 6.2` and
`swiftLanguageModes: [.v5]` (language mode 6 deferred per [04 §4.4](../research-2026-07/04-cross-platform.md);
`SWIFT_VERSION` in the app target stays `5.0`). Dead availability / dead files are gone; the app is
dark-locked; tvOS page background is `Color.black`. Phase 1 insets, focus owners, button metrics and
player quick wins are in. D1 (Home hero / banner) and D2 (poster sizing) are decided — see below.
**Phase 2a–2d landed** (`ShelfMetrics`, episode-card landscape captions, prominent hero buttons,
private `variableBlur`). **Home banner v1 landed:** horizontal shelf of contained 16:9 cards
(up to 6 sampled from catalog shelves); Netflix `showsFeaturedPreview` path deleted. Remaining
Phase 3 work is detail-page / shell polish (hero focus bugs, tabs refactor, etc.).

---



## Phase 0 — Unblock the baseline

Nothing below Phase 0 compiles until this is done. No visible change; do it in one PR.

- [x] **Raise the five packages.** All of them still say
  ```
  `platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v17)]` — `KinoPubUI/Package.swift:8`,
  `KinoPubBackend/Package.swift:9`, `KinoPubKit/Package.swift:8`,
  `KinoPubLogging/Package.swift:8`, `KinoPubMetadata/Package.swift:7`. Until `KinoPubUI` is on
  26, `glassEffect` cannot be used in `MediaCardView` / `MediaRowsView` /
  `MediaActionButtonStyle` — i.e. every card and every button in the app.
  → `platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26)]`
  ```
- [x] `swift-tools-version: 6.2` in all five (`.v26` requires PackageDescription 6.2, not 6.0;
  ```
  see [04](../research-2026-07/04-cross-platform.md)). App `SWIFT_VERSION` stays `5.0` with
  `swiftLanguageModes: [.v5]` on packages — language mode 6 deferred until `@Observable`
  (see [04 §4.4](../research-2026-07/04-cross-platform.md)).
  ```
- [x] **Delete dead availability branches.** All of these are unreachable at baseline 26:
  - `TabsNavigationView.swift` — `if #available(iOS 18, tvOS 18, macOS 15)`, and the whole
  `legacyTabs` fallback
  - six `@available` attributes on 18/15 across the TabView trees
  - `SubtitleTranslatePanel.swift` — `#available(macOS 15, iOS 18)`
  - `ProgressiveBlur.swift` — `#available(iOS 17, tvOS 17, macOS 14)` and the five-layer
  `.blur` fallback underneath it
  - **Kept** `@available(tvOS 27.0, *)` on `tabViewSidebarHeader`
- [x] **Delete dead files.** Zero production references:
  ```
  `KinoPubButtonTextStyle.swift`, `Image+CenterCropped.swift`, `ToastContentView.swift`,
  `WidthThresholdReader.swift` (and its pbxproj entries).
  ```
- [x] **Dark appearance only, app-wide.** `.preferredColorScheme(.dark)` at the scene root
  ```
  (`KinoPubAppleClientApp.swift`, including the macOS player window and Settings). 
  `INFOPLIST_KEY_UIUserInterfaceStyle = Dark` was already set in `project.pbxproj`.
  ```
- [x] **Give tvOS a real background colour.** `Colors+Extension.swift` now returns `Color.black`
  ```
  on tvOS (was `.clear`).
  ```
- [x] Verify the project still builds for all four platforms (tvOS / iOS Simulator / macOS).
  ```
  Package tests: Backend / Kit / Metadata green; KinoPubUI has a pre-existing
  `RatingTests.testTierBoundaries` failure unrelated to this phase.
  ```

---



## Phase 1 — Quick wins that are visible the same day

Small, low-risk, no architecture. Each is independently shippable.

### Grid and insets

- [x] `MediaRowsView.swift` — `horizontalInset: 48 → 80`. Everything else in the app is already
  ```
  80. Home's left edge currently misses every other screen's by 32pt.
  ```
- [x] `MediaRowsView.swift` — `cardSpacing: 36 → 40` (HIG gutter).
- [x] `SeasonsRailView.swift` — `contentMargins(.horizontal, …)` already used
  ```
  `Self.horizontalInset` (= 80 on tvOS); confirmed, no change needed.
  ```



### Focus

- [x] `MediaRowsView.swift` and `ContentItemsListView.swift` — drop
  ```
  `priority: .userInitiated`. It means "always, whenever focus enters this branch", so every
  return from the detail page throws focus back onto the first card of the first row.
  ```
- [x] Delete the duplicate focus owners layered on top of it: the `.task { sleep(120ms);
  ```
  focusedCard = … }` blocks and the `hasClaimedFocus` flag in both files. One owner:
  `defaultFocus`.
  ```
- [x] `MediaCardView.swift` poster — add explicit `.hoverEffect(.highlight)`. `.borderless` attaches
  ```
  its effect to the first **`Image`** in the label, and ours is an `AsyncImage`; we were probably
  getting no system lift/specular/tilt on cards at all.
  ```
- [x] `MediaRowsView.swift` — add `.scrollClipDisabled()` and `.focusSection()` on the row,
  ```
  and move `.buttonStyle(.borderless)` from each `ForEach` element out onto the shelf.
  ```
- [x] `SeasonsRailView.swift` — `.focusScope` replaced with `.frame(maxWidth: .infinity) +
  ```
  .focusSection()` on the tab strip; deleted the `focusBridge` hack (`Color.clear.frame(height:
  8).focusable()`), `bridgeFocused`, `episodeHadFocus` and the `onChange(of: bridgeFocused)`.
  Episode rail also gets `.focusSection()` + `defaultFocus`.
  ```
- [x] `MediaItemView.swift` — migrate the one-parameter `onChange(of:)` calls to the two-parameter
  ```
  form (also `TabsNavigationView` selected-tab handler).
  ```



### Buttons and metrics

- [x] `MediaActionButtonStyle.swift` — deleted the `.frame(height:)` immediately after
  ```
  `.frame(minHeight:)`. Same shape in `KinoPubButton.swift` (`maxHeight: 40` →
  `minHeight: 40`), and `ShortcutView.swift` (drop the frame entirely).
  (`KinoPubButtonTextStyle` was deleted in Phase 0.)
  ```



### Player

- [x] `PlayerView.swift` — remove the `GeometryReader { _ in … }` that wraps the whole player and
  ```
  uses nothing.
  ```
- [x] Fill `externalMetadata` in `PlayerManager.configureExternalMetadata()`: artwork, description,
  ```
  genre (title/subtitle were already there). Content rating has no honest kino.pub field yet.
  ```
- [x] `controller.speeds = AVPlaybackSpeed.systemDefaultSpeeds` and
  ```
  `controller.allowsPictureInPicturePlayback = true` on the tvOS `TVVideoPlayer`.
  ```
- [x] Delete `selectEmbeddedEnglishTrackIfNeeded` (`PlayerManager.swift`) — the Stream survey found
  ```
  0 embedded tracks in 189 items; it can only mis-fire.
  ```

---



## Phase 2 — One layout system, one glass helper

This is the bulk of "make it look modern". Days, not hours.

### 2a. `KinoPubUI/Layout/` — the single source of metrics

Today metrics are spread over nine `#if os` blocks in as many files (`MediaCardView.swift:344-382`,
`MediaRowsView.swift:310-345`, `SeasonsRailView.swift:580-600`, `MediaItemLayout`,
`MediaItemHeroView.swift:875-910`, `MediaActionMetrics`, `MediaItemInfoColumns`,
`MediaItemSheetLayout`, `PosterStyle`).

- [x] New `Packages/KinoPubUI/Sources/KinoPubUI/Layout/`: `CardAspect.swift` (2:3 / 16:9 / 1:1),
  ```
  `ShelfMetrics.swift` (inset / gutter / columns derived from container width + Dynamic Type),
  `Metrics.swift` (hairlines, radii, spacing — all `@ScaledMetric`), `TypeScale.swift` (text
  styles only; `.system(size:)` banned). Sketch is written out in
  [01 §4.2 MED-1](../research-2026-07/01-layout.md).
  ```
- [x] `MediaCardView` stops knowing its own width: `.aspectRatio(aspect.ratio, contentMode: .fit)`,
  ```
  title as `.frame(maxWidth: .infinity)` not `.frame(width:)`.
  ```
- [x] Rows size cards with
  ```
  `.containerRelativeFrame(.horizontal, count: metrics.columns, span: 1, spacing: metrics.gutter)`
  + `.safeAreaPadding(.horizontal, metrics.inset)`. Note: `containerRelativeFrame` reads safe
  area, **not** `contentMargins` — use `safeAreaPadding` or the column arithmetic drifts.
  ```
- [x] Poster width is **derived from the column model**, not a one-off design token. Target ~**6
  ```
  columns** in horizontal shelves (same sizing model as gallery grids) so posters grow with
  container / screen the way the Apple TV app does. See **D2**.
  ```
- [x] `SeasonsRailView` caption — replace `.frame(width: cardWidth - captionPadding * 2)`
  ```
  arithmetic with padding + `maxWidth: .infinity`.
  ```
- [x] Delete the `width: CGFloat` parameter from `ContentItemsListView` and the
  ```
  `GeometryReader` pumps feeding it (`CatalogView`, `SearchView`, `BookmarkView`,
  `PersonItemsView`).
  ```
- `MediaItemInfoColumns` → `Grid`/`GridRow` + `gridColumnAlignment(.leading)`. Removes
  ```
  `columnWidth`, `keyWidth`, `sheetKeyWidth` and lets the existing `ViewThatFits` finally
  measure real content instead of a sum of constants.
  ```
- [x] `PosterStyle` → one aspect, no `AnyView`. Fixes `SeasonItemView` placeholder sizing.



### 2b. Cards — one landscape style, one poster style, identical behaviour

**Decided.** The episode card in `SeasonsRailView.swift:465-580` is the model. It gets the layout
right and everything else copies it:

- caption lives **outside** the image, under it — title (up to 3 lines) then
`EPISODE 12 · 5 Mar` uppercase secondary. Nothing is written over the artwork, so there is no
bottom strip to blur and no fade to fake.
- progress bar sits pinned to the **bottom edge of the still**, inside the image bounds
(`SeasonsRailView.swift:558-580`). That reads correctly and costs nothing.
- uniform row height comes from a hidden caption scaffold (`captionReserve`, `:498-509`) — keep the
idea, but re-derive the width from `ShelfMetrics` instead of `cardWidth - captionPadding * 2`.

Right now the two card types are not one system at all. On **tvOS** `MediaCardView` has *no*
overlays whatsoever — no rating, no badge, no progress, no playback footer; all of it is behind
`#if !os(tvOS)` (`MediaCardView.swift:223-258`), with a comment admitting "score/progress can return
as text in the caption if wanted". So on the primary platform a Continue Watching card shows no
resume bar and no `S2, E5 · 42 min` at all, while the episode rail two screens away shows both. The
split exists because `playbackFooter` needed `ProgressiveBlur` behind it to stay legible over
artwork, and the blur is what broke on tvOS — not because the footer's content was wrong for TV. The
episode-card layout does not need that blur (progress sits on a bare image edge, nothing translucent
over the picture), so the platform split has no reason to survive it.

- [x] **Landscape card adopts the episode-card layout, in three pieces:**
  - **Play glyph stays on the artwork**, alone — bottom-left corner, icon only, no bar and no label
  next to it. This is the one piece of `playbackFooter` that stays an overlay.
  - **Progress bar moves to the still's bottom edge**, episode-card style — pinned to the image,
  not floating in a translucent strip.
  - **Labels move below the image**, into the caption, alongside the title — keep exactly what
  Continue Watching's `overlayLabel` (`S2, E5 · 42 min`) already got right, just relocated.
  **No ⋯ overflow button on the card** (D7 skipped — long-press context menu only).
- [x] That removes the only reason `ProgressiveBlur` was still in the card — no strip over the
  ```
  artwork means nothing to blur on that card.
  ```
- Once both cards share one caption+progress structure, fold the episode card in
  ```
  `SeasonsRailView` into `KinoPubUI` rather than leaving a second implementation.
  ```

**Poster card overlays.** These *do* sit on the artwork, and there is a real constraint: on tvOS
every extra image layer inside a `.borderless` label gets its own highlight and the focus effect
fragments — that is why the overlays were removed in the first place. The answer is not "no
overlays", it is binding the effect explicitly.

- Bring the poster overlays back on tvOS behind an explicit `.hoverEffect(.highlight)` on the
  ```
  card container plus `HoverEffectGroup` so the layers highlight as one, not four
  ([06 §4.1-4.2](../research-2026-07/06-tvos-focus.md)). Verify on a real remote — if the group
  still fragments, fall back to a single pre-composited overlay layer. (iOS/macOS keep existing
  rating + badge overlays today.)
  ```
- [x] **Badge slots — keep existing working badges; do not invent a new system now (D10).**
  ```
  Designer defines award / “weeks in top” / Kinopoisk top / premiere treatment later. App already
  collects that data. Existing score + count badge on non-tvOS stay.
  ```
- **Behavioural identity is the acceptance criterion.** Same focus animation, same caption
  ```
  reveal rule, same progress semantics, same watched treatment — a poster card and a landscape
  card must differ only in aspect ratio and which slots have content.
  ```
- [x] Data availability: do not block on editorial badge content — deferred with D10.



### 2c. Liquid Glass, through one helper

Glass belongs on **system chrome** (nav / scroll / filters) where it matches the platform —
**not** as a Phase gate, and **not** forced onto the hero. Hero CTAs are plain / translucent /
transparent buttons with clear primary vs secondary prominence (white Play pill + circular
secondaries). D3 (`.glassProminent` / `.glass`) is an **optional later supplement** for non-hero
surfaces if it reads better than current chrome.

- [x] New `KinoPubUI/DesignSystem/KinoGlass.swift` — the only place `glassEffect` is written, with
  ```
  `accessibilityReduceTransparency` / `colorSchemeContrast` degradation built in, modelled on
  `silo-apple/.../DesignSystem/SiloGlass.swift`. Call sites never write `glassEffect` directly.
  ```
- [x] Port `DevicePower.isLowPowerAppleTV` (utsname → `AppleTV<major>`). Glass over *playing video*
  ```
  re-samples the backdrop every video frame; on A12 boxes substitute an opaque fill.
  ```
- [x] `MediaActionButtonStyle` — **hero buttons: prominent primary + circular secondary, not glass.**
  ```
  Play = solid white pill at rest; secondary circles / pills = translucent white plate; focus
  scales and inverts. Do not pile `.glass` onto the hero CTA row.
  ```
- `LibraryFiltersBar` / `SubtitleTranslatePanel` / `MainView` material cleanups — optional when
  ```
  touching those files; prefer system glass only where it matches scroll/nav chrome.
  ```
- Collapse the 16 custom `ButtonStyle` types down (separate pass).



### 2d. Replace Metal ProgressiveBlur with private `variableBlur`

Do **not** invent a third blur stack. Target: one helper that uses private `CAFilter`
`variableBlur` + gradient mask (VariableBlur.swift / jtrivedi pattern) for hero/banner/card
overlays that need the Music–Journal look.

- [x] The `ProgressiveBlur` call in the card playback footer disappears with 2b — no strip over
  ```
  the artwork means nothing to blur on that card.
  ```
- [x] `ProgressiveBlur` **rewritten as private-**`variableBlur` **overlay** (D9). Metal
  ```
  `Shaders/VariableBlur.metal` deleted. Call sites place it *on top of* static art in a ZStack.
  Platform rules:
  - **tvOS + macOS:** blur over **static images** OK; **no blur over video** on the hero
    (pass `isEnabled: false` while trailer is showing).
  - **iOS + iPadOS:** blur OK over **images and video**.
  ```
- Apply the helper on detail/Home hero/banner overlays (Phase 3 banner rebuild + detail
  ```
  backdrop pass). Featured-preview path already uses the overlay where still enabled.
  ```
- [x] Drop the `xcodebuild -downloadComponent MetalToolchain` requirement from README when the
  ```
  Metal asset is gone. (Tied to **D9**.)
  ```



### 2e. Typography and accessibility

- Replace remaining `.system(size:)` calls with text styles (card/shelf titles moved to
  ```
  `TypeScale` in 2a; detail / hero / seasons still to go).
  ```
- `@ScaledMetric` on every square/hairline dimension: actor portraits, circular buttons, tab
  ```
  icons, progress bars, player controls.
  ```
- `MediaCardView` gets an `accessibilityLabel`.
- `RatingBadgeView` — rating tier is encoded **only** by colour. Add a non-colour differentiator.
- De-duplicate the two initials-avatar implementations into one atom.
- One `AsyncImage` atom instead of 15 call sites.

---



## Phase 3 — Detail page, hero and the tvOS shell

D1 (Home banner direction + blur policy) is signed off. **Home banner v1 landed** as a
horizontal shelf of contained 16:9 cards (not full-bleed; no CTAs; random sample from
catalog shelves). Remaining items below are detail/shell polish. D4–D6 / D8 do not
block. D3 is optional and does **not** apply glass to hero CTAs. Blur stack (Phase 2d /
D9) is landed.

- [x] **Hero on Home — contained banner shelf (v1).** Deleted the Netflix-style
  ```
  `showsFeaturedPreview` path (560pt spacer, full-bleed backdrop, focus-driven preview).
  Home shows up to six contained 16:9 cards (`HomeBannerCardView` + `ShelfMetrics.banner`):
  wide backdrop, inset vertical poster, titles + IMDb/Kinopoisk scores, private
  `variableBlur` over static art. No CTAs. Data: random unique sample from catalog
  shelves (not Continue Watching). Full-bleed single hero / shared `MediaItemHeroView`
  variant / curated set deferred.
  ```
- Target banner look polish: optional page dots / L-R only if a carousel is
  ```
  straightforward later; CTAs if we want parity with detail later. Text legibility via
  **private `variableBlur` over static art**; on tvOS/macOS, no blur while video is showing.
  ```
- tvOS tab background: `containerBackground(for: .tabView)` where useful (old
  ```
  `.ignoresSafeArea()` backdrop path is gone with the featured preview).
  ```
- Detail hero height → `containerRelativeFrame(.vertical)` (kill hard-coded detail
  ```
  `heroHeight = 1080`). Banner cards already size from `CardAspect.landscape`.
  ```
- **Card → detail transition:** desire is classic Apple morph, but prefer default /
  ```
  system-achievable navigation beauty over a custom hero morph. Historical third-party morphs
  looked worse than none — **abandon custom morph** unless it is cleanly doable with stock
  APIs. Simple push/navigation is the default.
  ```
- `MediaItemHeroView` — four different buttons all `.focused($focus, equals: .heroOther)`
  ```
  (`:635,653,663,703`). Same `@FocusState` value on several views is undefined behaviour on
  programmatic writes. Give them distinct values, and add `.focusSection()` on the button row.
  ```
- `MediaItemView.swift:142-161` — the two-slide "slideshow" driven by `.offset(y:)` + `.clipped()`
  ```
  with both slides always in the hierarchy and both `.focusSection()`. tvOS resolves focus from
  **layout frames**, so focus can land on an invisible, clipped control. Highest-risk area on the
  detail page; move the geometry with layout, not offset. Verify on a real remote before and
  after.
  ```
- [x] Trailer: lives **inside detail / player**, not as a requirement of the Home banner. Home v1
  ```
  stays on **static images**; detail may keep muted trailer takeover when `trailer.url` exists.
  While video is showing: **no blur on tvOS/macOS**; **blur allowed on iOS/iPadOS** (same
  variableBlur helper).
  ```
- `SubtitleTranslatePanel.swift:168-178` — the word chips have no `@FocusState`, no 
  ```
  `defaultFocus`, no `focusSection`. Focus is undefined when the panel opens.
  ```
- `TabsNavigationView.swift` — 630 lines, three near-identical platform trees. After Phase 0
  ```
  deletions this should land around 240-280. Bring tvOS in line with the macOS tree
  (`TabSection` Browse / Library / Folders — available on tvOS since 18.0). Replace
  `.buttonStyle(.plain)` on the profile button (`:121`, `:311`) — AGENTS.md warns against it and
  it may be what makes the sidebar row visually inert.
  ```
- **Known ceilings, so nobody plans around them:** `TabViewCustomization` is
  ```
  `@available(tvOS, unavailable)` — hiding, reordering and badging tabs is impossible on tvOS in
  both 26 and 27. `.tabBarMinimizeBehavior`'s useful values are iPhone-only. On tvOS,
  `searchable` suggestions support **`Text` only**, and `.searchFocused` / programmatic field
  presentation are unavailable.
  ```

---



# ⛔ STOP HERE

**Phases 0-3 are the agreed scope. Do not start Phase 4 without a fresh decision round.**

The player is its own problem and it does not get fixed as a tail of the UI work. What is there now
was built by inventing around the platform instead of using it, and the result is worse than not
having done it:

- **Hand-rolled subtitles that should have been a Settings option.** Subtitle *appearance* — size,
colour, background, opacity — is a system feature: Settings → Accessibility → Subtitles &
Captioning, read through `MediaAccessibility`. Instead `SubtitleOverlayView.swift:18,33-47`
hardcodes 34/22pt white-with-a-shadow and ignores the user's setting entirely. Whatever custom
rendering genuinely has to stay (sidecar SRT attachment and dual tracks *are* impossible natively
— see [05 §1.4](../research-2026-07/05-player-media.md)) must still take its styling from the system
and expose its own options in our Settings screen, not in the player.
- **Switching subtitle tracks mid-stream crashes.** Reported, reproducible, not diagnosed. Nothing
else in Phase 4 matters until this is understood — start from `PlayerManager` track selection and
the sidecar-vs-embedded path, and get a symbolicated trace before touching anything.
- **A custom centre overlay for information that AVKit already renders.** The player draws its own
panel in the middle of the screen for things the system shows natively — the Info panel,
`contextualActions`, the transport bar's own chapter/track UI. This is the exact thing AGENTS.md
forbids ("no custom chrome where a system control exists"), and it is why the player feels
non-native. The fix is not to restyle the overlay, it is to delete it and populate the native
surfaces (`externalMetadata`, `contextualActions`, `infoViewActions`, `navigationMarkerGroups`,
`customOverlayViewController`).

So Phase 4 below is a **backlog, not a work order**. Before any of it starts we need one pass that
decides: what the player is allowed to draw itself, what moves into Settings, and what the crash
actually is. Until then, the only player items in scope are the three already listed in Phase 1
(remove the dead `GeometryReader`, fill `externalMetadata`, `speeds` + PiP) — none of which touch
subtitles or track selection.

---



## Phase 4 — Player (backlog, blocked)

Full list in [05 §4](../research-2026-07/05-player-media.md). The correctness bugs here are not
cosmetic and several are user-visible today — but see the stop above: this list gets re-scoped
before it gets worked.

- **Fix the resume race.** `PlayerView.swift:80` (`.onAppear` → `fetchWatchMark` → seek) and
  ```
  `:104` (`.task` → `preparePlayback` → `replaceCurrentItem` + play) run in undefined order, so
  the seek often lands on an empty or stale item. One `.task`: prepare → wait for
  `.readyToPlay` → seek with `toleranceBefore/After: .zero` → play. This is the "continue
  watching doesn't always work" report.
  ```
- **Resume reads the wrong episode.** `PlayerManager.swift:382` uses
  ```
  `videos?.first / seasons?.first?.episodes.first`. Episode 7 resumes at episode 1's timestamp.
  Same root cause as the known `MediaItem.subtitles` bug — `Models/MediaItem.swift:260,264,268,272`
  all read `videos?.first`, so for a series the entire `PlayableItem` describes S1E1.
  ```
- **Skip Intro, natively.** `AVPlayerViewController.contextualActions` (tvOS 15+) *is* Apple's
  ```
  Skip pill. Chapters via `AVPlayerItem.navigationMarkerGroups`. v1 data can come from the SRT
  we already download (gap between cues in the first 8 minutes) — no new service needed.
  ```
- **Subtitle overlay respects the system.** `SubtitleOverlayView.swift:18,33-47` hardcodes
  ```
  34/22pt, white, with a shadow, and ignores Settings → Accessibility → Subtitles entirely.
  Use `MediaAccessibility`, host it as `customOverlayViewController` inside
  `AVPlayerViewController` (not a SwiftUI sibling in a `ZStack`), and lay it out against
  `unobscuredContentGuide` so the transport bar stops covering it. Also: it currently hides on
  pause (`PlayerView.swift:122` gates on `isPlaying`), which is backwards for the
  language-learning use case.
  ```
- Encoding and validation on the SRT fetch: Russian subtitles are routinely windows-1251, and
  ```
  the current `.utf8 ?? .isoLatin1` chain "successfully" decodes them into mojibake. Add an HTTP
  status check — a 404 page currently parses to 0 cues and silently disables subtitles.
  ```
- Cue lookup: binary search + cursor instead of a linear scan over ~2000 cues four times a
  ```
  second (`PlayerManager.swift:341`, `SubtitleCueParser.swift:76`).
  ```
- Drop the second periodic observer and stop publishing `currentPlaybackTime` four times a
  ```
  second — it invalidates the whole `PlayerView` for the length of the film and is read nowhere.
  ```
- `PlayerTimeObserver` fires its callback on `.global(qos: .userInteractive)`, so
  ```
  `saveWatchMark` and `persistAudioSelectionIfNeeded` touch `currentMediaSelection` and
  `UserDefaults` off the main thread. Also `if time.seconds > 60.0` at `:31` means nothing
  shorter than a minute ever gets a watch mark.
  ```
- `Task.detached(priority: .utility) { [unowned self] … }` at `PlayerManager.swift:364` — a
  ```
  detached task outliving the manager with `unowned` is a crash on exit. `[weak self]`.
  ```
- `HLSAudioLabeler.swift:34-38` writes a temp `.m3u8` per launch into `tmp/kinopub-hls` and never
  ```
  deletes it; `:47` splits on `\n` without stripping `\r`, which corrupts the attribute list on
  a CRLF playlist (kino.pub sends LF today — latent, not theoretical).
  ```
- `BestVideoQualityFinder` — `UIScreen.main.bounds` is deprecated and reports 1920×1080pt even on
  ```
  Apple TV 4K; the `.wifi` check inverts its own intent on a wired box; macOS picks
  `files.first` (the *lowest* quality); an empty list returns `""` → `nil` URL → silent no-play.
  And the deeper point: `hls4` is already a master playlist with an ABR ladder, so picking a
  "file" by resolution is choosing a ladder inside a ladder.
  ```

---



## Decisions already made

Settled — no further sign-off needed, these are in the phases above.

- **Dark appearance only** for now, app-wide, including system chrome. Light comes back as its own
pass once dark is good. (Phase 0)
- **One landscape card style**, modelled on the episode card in `SeasonsRailView`: caption outside
the artwork, progress on the still's bottom edge, nothing written over the picture. The playback
footer over the artwork goes away. (Phase 2b)
- **Poster card keeps overlays on the artwork** — score, count badge, status badge, watched state —
behind an explicit hover effect so the tvOS focus highlight does not fragment. (Phase 2b)
- **Behavioural identity between the two card types** is the acceptance criterion, not a
nice-to-have: same focus animation, caption rule, progress semantics, watched treatment and badge
slots. Only aspect ratio and slot occupancy differ. (Phase 2b)
- **Player is out of scope** until it gets its own decision round. (see STOP above)



### D1 — Home hero / banner — **decided** (2026-07-28)

Home gets an **Apple TV–style banner**, not the old Netflix-style absolute preview of whichever card
is focused (that approach clipped shelves and was abandoned for cheaper solutions — **do not
revive it**). Ideal end state: the **same component as the detail hero**, possibly a **simplified
variant** with slightly less info. This is a **full layout rebuild** of Home's top, not a polish
pass on `showsFeaturedPreview`.

**Reference look** (Apple TV app banner, e.g. Cape Fear): full-bleed cinematic art across the content
width; editorial/title treatment; short meta (type / genres / age); short plot; **primary white pill
CTA + secondary circular actions** (plain / translucent — **not** liquid-glass overlays on the hero);
page dots and edge chevrons when (later) it is a carousel. Legibility from **Music/Journal-style
variable blur** over static art (plus a subtle dark gradient if needed), not a soft-edge-only
underthink and not a Netflix focus-preview slab.

**Decided for v1:**

- Banner on Home: **yes**, Apple TV style.
- Shared / simplified hero component with detail: **yes**, preferred.
- **No** Netflix-style focus-preview overlay driving the banner from shelf focus.
- **Variable blur on hero stays** — recreating Apple’s progressive/variable blur is part of the
modernization point. Platform rules:
  - **tvOS + macOS:** blur **OK over static images**; **no blur over video** on the hero.
  - **iOS + iPadOS:** blur **OK over images and video**.
  - Small cards with image backgrounds: variableBlur OK where it looks good and isn’t expensive.
- Card → page morph: **prefer system / default navigation beauty**; abandon custom hero morph if it
is not cleanly doable (past third-party attempts looked worse than none).
- Trailer: **inside detail / player**, not a Home-banner requirement. Home can use **static images**.
- Shelves under the banner: **normal cards, larger** (see D2) — not a special "preview shelf".



#### Blur technical approach (hybrid, Apple-first) — **decided** with D1 correction


| Context                                                                  | Approach                                                                                                                    |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| Nav / toolbar / scroll chrome over lists                                 | Prefer **system** iOS 26 scroll-edge effect + `safeAreaBar` / toolbar (public, free)                                        |
| Hero / banner / card overlays needing Music–Journal look over **images** | **Private** `CAFilter` ****`variableBlur` **+ gradient mask** (VariableBlur-style). Personal project → private API accepted |
| Hero over **video**                                                      | **tvOS + macOS: no blur**; **iOS + iPadOS: blur allowed** (same variableBlur path)                                          |
| Small image-backed cards                                                 | variableBlur OK where it looks good and isn’t expensive                                                                     |


**In-repo path:** replace hand-rolled Metal `ProgressiveBlur` / `VariableBlur.metal` with the private
`variableBlur` helper (thin in-repo wrapper). Do not add BlurUIKit unless we already depend on it
(we do not). Do **not** use `scrollTransition` for this (different effect). Approximations
(`UIVisualEffectView` + mask, WWDC public shaders) are fallbacks only if private filter fails —
not the primary strategy.

#### Banner / Hero follow-ups (deferred thinking — not blocking the decision)

Track these when implementing Phase 3; none reopen "do we have a banner?":

1. **Carousel vs static banner.** Left/right paging with dots is **not assumed OOTB**. If it is not
  straightforward, **cut the carousel for now** — ship a single static banner (or simple non-paged
   featured slot) and revisit carousel as a later item.
2. **Same component as detail hero**, simplified content on Home — confirm the shared API (what Home
  omits: meta density, trailer, secondary actions).
3. **Trailer placement** — detail/player; Home banner stays static unless a later pass adds optional
  muted trailer without regressing performance (and respects the video blur rules above).
4. **Larger normal cards on Home** — sizing owned by D2 / `ShelfMetrics`, not by the banner.
5. **No Netflix-style focus preview** — delete dead `showsFeaturedPreview` path rather than
  re-enabling it.
6. **No custom card→page hero morph** unless trivially system-nice; default to simple navigation.
7. **Hero variable blur** via private `variableBlur` (D1 + Phase 2d); disable over video on
  tvOS/macOS; keep on iOS/iPadOS even over video.



### D2 — Poster sizing — **accepted / proceed** (2026-07-28)

Posters **should scale with the grid / screen**, not sit on a one-off "260pt design token" that
defines the look. Target: horizontal shelves use the **same sizing model as gallery grids** — e.g.
~**6 columns**, proportional like the Apple TV app, so posters grow with container width.
Breakpoints, `containerRelativeFrame` column counts, or text-in-card layout that drives size (Apple
style) are all fine. **Fixed width is OK as a temporary / simpler fallback** (looks worse) but is
not the preferred end state.

This is **not** a blocking "UI redesign language" decision — sizes do not define the design system.
**Proceed in Phase 2a** with proportional sizing preferred.

### D9 — Blur stack: replace Metal with private `variableBlur` — **decided** (with D1 correction)

Do **not** delete hero blur. Rewrite/replace `ProgressiveBlur.swift` + `Shaders/VariableBlur.metal`
with an in-repo private `CAFilter` `variableBlur` + gradient-mask helper; then drop the Metal asset
and the `MetalToolchain` README requirement. System scroll-edge covers list/nav chrome; private
filter covers hero/banner/card overlays per D1 platform rules. Fallbacks only if needed:
`UIVisualEffectView` + mask, or public WWDC progressive-blur demos — not BlurUIKit dependency, not
`scrollTransition`. Implement in Phase 2d.

## Design decisions — settled / deferred (no invented blockers)

D1, D2 and D9 are under **Decisions already made**. The items below are **not** Phase 2 gates.

**D3. Play/action buttons / glass — optional, not a blocker.** Hero CTAs are **not** liquid-glass
overlays (that was a hallucination). Apple TV hero buttons are plain / translucent / transparent
with clear primary vs secondary (white Play pill + circular secondaries). Current
`MediaActionButtonStyle` follows that. System `.glass` / `.glassProminent` may still be useful later
on non-hero chrome (filters, panels) — optional supplement, not required to ship Phase 2.

**D4. Badge row on the detail page** (4K · DV · Atmos · CC · SDH · AD, per the Mortal Kombat
reference). What we can honestly light up: resolution, AC3/channels, CC/SDH by heuristic, AD,
multi-audio, and age rating via Kinopoisk. **4K / HDR / Dolby Vision / Atmos cannot be shown** —
the Stream survey found every kino.pub stream is avc1 8-bit + AAC, SDR, ≤1080p. Decision: reserve
space for them or omit them entirely. (Phase 3 polish — does not block static banner.)

**D5. Title logo art instead of a text title in the hero** (TMDB serves `logos`). Matches Apple TV;
changes the look of the header substantially. (Applies to the shared banner/hero component from D1.)

**D6. Inline "MORE" pill** at the end of the truncated synopsis instead of a separate button.
Moves a control.

**D7. "···" on Continue Watching — SKIP for now.** Three-dots is a non-touch affordance hinting at
context/long-press menus. Do **not** add an extra ⋯ button on the card; long-press context menu
stays.

**D8. Search: full-width field in the toolbar with a result counter** (WWDC app reference). On tvOS,
suggestions are `Text`-only — no posters in the suggestion list — and the field cannot be focused or
presented programmatically.

**D10. Card badge design — DEFER to designer.** Not our job now. App already collects data for
awards / “weeks in top” / Kinopoisk top / premiere etc. Keep existing badges working; do not invent
a new badge-slot system or block Phase 2 on it.

---



## Native UI remediation (2026-08)

Checklist for the attached remediation plan (do not edit the plan file itself):

- [x] Synopsis truncation + native More/sheet; Watchlist routing; route Equatable + identity tests
- [x] Home material + `backgroundExtensionEffect`; banner loading atom; viewAligned snapping; poster rating
- [x] tvOS poster lockup overlays; `SectionHeader`; `MediaCapabilityBadges` model + hero/poster chips
- [x] Semantic `TypeScale` / MarqueeText; system filters chrome; a11y labels; localization fills
- [x] Unified `Route` + `RouteDestination`; macOS `tabViewSidebarBottomBar`; `Tab(role: .search)`
- [x] `matchedTransitionSource` / `navigationTransition(.zoom)` on iOS/tvOS (poster/banner/cast)
- [x] Detail page single `ScrollView` focus graph (offset slideshow removed)
- [x] App-scoped `PlaybackSession` + shared player hosting

**Provisional:** tvOS remote matrix via Device Hub not yet driven in this pass — mark simulator-only.