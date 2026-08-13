# Plan: detail-page choreography (hero → sections)

> **Archived 2026-08-13.** The table below is what survived. Everything else is evidence.


> ## ⛔ Superseded in large part — 2026-08-13
>
> Read everything below as **evidence of what was tried**, never as requirements. A user review on
> 2026-08-13 went through what this page's documentation had turned into and voided the parts that
> were workarounds wearing a requirement's clothes. Living rules now live in
> [constraints-and-requirements](../../../AGENTS.md),
> [apple-native-design](../../../AGENTS.md),
> [component-catalogue](../../../AGENTS.md) and
> [focus-and-tvui](../../../.claude/skills/tvos-surface/SKILL.md).
>
> | In this plan | Now |
> | --- | --- |
> | Continuous scroll progress driving every layer (phase 0, `washProgress`, the fold-snapping passes) | **Void.** Two discrete states, one writer, derived from focus |
> | Hero **outside** the scrolling container (phase 1) | **Void as written.** The *artwork layer* is behind the scroll; hero content stays in one focus graph with the sections |
> | Overlay header with the title logo (phase 2) | **Dropped.** No compact title, no floating logo, unless navigation chrome needs one |
> | Hand-driven `contentOffset` / `CADisplayLink`, "re-file from rejected to required" | **Banned again.** We do not replace the focus engine's scroll animator |
> | Sections as data (phase 3) | **Stands** — and the playable rail comes first |
> | Empty / error state is focusable content (the invariant) | **Stands**, promoted to a platform invariant about focus escape paths |
> | Tab bar pinning (the "no API lever on tvOS" notes) | **Not a requirement at all.** System `TabView`; whatever it does on scroll, it does |
> | Row landing rules, per-frame chrome maths, the reference app's race guards | **Not ours to port.** tvOS heavy surfaces move to UIKit + TVUIKit, where the engine does this |
>
> The SDK facts, the on-device focus findings (`heroOther`, stranded posters, season-tab defaults)
> and the TVUIKit gallery notes remain useful and are unaffected.

> **Dated implementation plan — not living authority.** Focus rules:
> [focus-and-tvui](../../../.claude/skills/tvos-surface/SKILL.md). Material rules:
> [materials-blur-and-chrome](../../../.claude/skills/apple-chrome/SKILL.md). Layout:
> [layout-and-containers](../../../.claude/skills/apple-chrome/SKILL.md). Accepted behavior:
> [01 — Foundation](../../../ROADMAP.md) § Focus, navigation, chrome.

Date: 2026-08-09. Status: phase 0 landed. Phase 1 attempted and reverted same day (broke tvOS focus
+ Menu/back on-device) — root cause found and fixed same day (see below) — needs its own retry.
Phases 2–4 not started. Second on-device pass same day found and fixed several more chrome bugs
(shadow removal, tab bar, rating/vote focus) — see "Shipped" below — and surfaced two bugs recorded
but deliberately **not** fixed yet (tab bar architecture, episode-rail ordering) plus a longer
Rivulet-alignment wishlist folded into new phases 5–8.

Scope: **the detail page only.** The reference app's preview carousel is explicitly out — it is the
laggy part and we are not copying it. What we want is what happens *after* you are on a title:
the hero, the scroll down into the sections, and everything that rides that one movement.

## Reference

Read from a local checkout of Rivulet (outside this tree). It is **PolyForm Noncommercial 1.0.0** —
technique only, never code, same rule as [community-fork](../../community-fork.md). Paths below are
theirs, cited as evidence for *why* a decision is what it is; they are not files we vendor.

Their detail surface is one `UICollectionView` (compositional layout, diffable snapshot) with
sections `episodes · trailers · extras · related · cast · about · info`, living under a fixed hero.
Three phases: carousel-stable → expanded-hero → details-stable.

## Where we actually are

| Piece | Us today |
| --- | --- |
| Scroll progress 0…1 | **Exists.** `onScrollGeometryChange` → `washProgress`, distance 600 ([MediaItemView.swift:214](../../../KinoPubAppleClient/Views/MediaItem/MediaItemView.swift:214)) |
| Backdrop scrub | **Dead.** `effectiveWash` returns `max(washProgress, 1)` — always 1 ([MediaItemHeroView.swift:236](../../../KinoPubAppleClient/Views/MediaItem/Subviews/MediaItemHeroView.swift:236)). The wash is a binary flip on `isHeroOnScreen`, not a scrub |
| Hero chrome fade | Exists, Rivulet's curve `1 - min(1, p·2.6)` floored at 0.35 ([MediaItemHeroView.swift:454](../../../KinoPubAppleClient/Views/MediaItem/Subviews/MediaItemHeroView.swift:454)) |
| Hero position | **Inside** the scrolling `VStack`, one viewport tall ([MediaItemView.swift:178](../../../KinoPubAppleClient/Views/MediaItem/MediaItemView.swift:178)) |
| Sections | A `VStack` of hand-written heterogeneous views, not a section list |
| Overlay header | None. Season rail is in the scroll flow |
| Blur | `.blur(radius: 12, opaque: true)` over a 120×180 buffer — a filter on a rendered frame, not a material |

`01-foundation` § Focus, navigation, chrome carries a `- [x]` for "scroll progress scrub" — that box
is **wrong** while `effectiveWash` pins to 1. Phase 0 either makes it true or the box comes off.

## The ten points, and where each one lands

Platform verdicts are the point of this table: several of these are tvOS-only medicine for a
tvOS-only disease, and shipping them elsewhere would be cargo cult.

| # | Mechanism | tvOS | iOS / iPadOS | macOS |
| --- | --- | --- | --- | --- |
| 1 | Hero **outside** the scrolling container | **Yes** — it is what stops focus moves between hero buttons from nudging the offset | Same structure, different reason (stretchy header under a collapsing nav bar) | Same structure — fixed toolbar over a scroll |
| 2 | One scroll progress driving every layer | **Yes** | Partly — the system already does chrome via `scrollEdgeEffectStyle`; own progress only for hero parallax/dim | Same as iOS, smaller role |
| 3 | Blur as a **scrubbed material**, not `.blur` | **Yes** — paused `UIViewPropertyAnimator` + `fractionComplete` on a `UIVisualEffectView` | **No** — fights the system nav-bar material | **No** — against toolbar convention |
| 4 | Overlay header: small title logo (+ season rail) | **Yes** | **Yes** — this is just the inline nav title swapping to the logo | **Yes** — window title / `toolbarTitleDisplayMode` |
| 5 | Row landing rules (first row pinned under the header, others centred, clamped at the ends) | **Yes** | **No** — no focus engine, nothing to solve | **No** |
| 6 | Sections as one lazy list built from data | **Yes** | **Yes** — same ordering and empty-section skipping | **Yes** |
| 7 | Full-width band behind the Information block as a section decoration | **Yes** | **Yes** | **Yes** — reads as a grouped band |
| 8 | "Related" is literally the Home shelf component | **Yes** | **Yes** | **Yes** |
| 9 | Empty / error state is **content**, not absence | **Yes — safety-critical** (see invariant below) | Yes — quality | Yes — quality |
| 10 | Two focus stops per episode card (thumb plays, text opens) | Open question — costs a pile of race guards | As **tap zones**: thumb plays, text opens | Click zones + context menu |

Explicitly **not** ported anywhere: their hand-driven scroll (`isScrollEnabled = false` +
`CADisplayLink` per-frame `contentOffset`) and the 60 ms same-press focus guards. Those exist to
beat the tvOS focus engine's own scroll animator. On iOS/macOS there is no such animator to beat,
and on tvOS we should reach for them only if phase 3 proves SwiftUI cannot land rows.

## Invariant this plan exists to protect

The reference app has a **one-way trap**: with no below-fold content (load failed, no connection)
`sectionKinds` is empty, so nothing down there can take focus — and `enterBelowFold` has already
flipped the phase and made the hero action row non-focusable. Up then finds nothing. You cannot get
back out of the page.

Three rules, promoted to living law in
[focus-and-tvui](../../../.claude/skills/tvos-surface/SKILL.md) § Project decisions:

1. Never move to a "scrolled into sections" state until at least one focusable row exists there.
2. Never drop the hero's focusability until focus has actually landed below. Our 0.35 opacity floor
   already does the visual half of this — make the focusability half explicit, not incidental.
3. Empty and error states are focusable sections with a Retry control, never an empty list.

## Phases

### Phase 0 — make the existing scrub real

- [x] Decided: continuous scrub. `effectiveWash` returned `max(washProgress, 1)` (always 1);
      changed to `washProgress` — already clamped 0...1 upstream by `MediaItemView`'s
      `onScrollGeometryChange` ([MediaItemHeroView.swift:236](../../../KinoPubAppleClient/Views/MediaItem/Subviews/MediaItemHeroView.swift:236)).
- [x] `01-foundation` § Focus, navigation, chrome corrected with a dated note (see below) rather
      than silently rewriting the old `- [x]`.
- [ ] **Verify on Device Hub that the scrub reads as intended.** Not done — no way to drive the
      tvOS remote (Up/Down/Select) from this environment: no `Simulator.app` on this Xcode install,
      and `simctl` has no directional-press API, only screenshots. Build + launch confirmed clean;
      visual confirmation is outstanding.

Smallest possible change; it tells us whether the whole direction is worth the next four phases.

### Phase 1 — hero out of the scroll — ATTEMPTED, REVERTED 2026-08-09

The `ZStack` sibling structure (hero as a fixed layer, `ScrollView` as a sibling) was implemented,
built cleanly, and **broke tvOS navigation on-device.** Reverted in full; back to hero as the first
item in the scroll `VStack`, exactly as before phase 0.

**Observed symptoms (on-device, real remote):**

- Focus could not leave Play at all — no route to the description or the buttons below it. Stuck.
- Down into the below-hero content worked **only** when the first section was a season rail (a
  show); for a movie, Down did nothing — there was apparently no reachable focus target below.
- Up out of the sections **never** worked, show or movie.
- **Menu closed the app instead of popping the detail page.** The most serious symptom — points at
  the `NavigationStack` / responder chain losing track of where it was, not just a focus-navigation
  inconvenience.
- Visually: the backdrop's own wash (`MediaItemHeroBackdrop`) faded correctly (top portion reads
  semi-transparent as expected), but the hero's title/actions did not — they stayed opaque and
  collided with the season rail's content once scrolled, because the season rail (and every other
  section) is far shorter than a full viewport and never actually covers the hero band the way the
  design assumed. This confirms the "0.35 floor bleeds through" risk flagged during implementation,
  compounded by content simply not being tall enough to occlude it.

**Working theory, not confirmed:** tvOS's spatial focus engine and `ScrollView`'s own
scroll-to-reveal machinery expect the focusable graph to nest normally; splitting hero and the
`ScrollView` into `ZStack` siblings — one a plain fixed view, one scroll-owned — broke both
directional continuity and, somehow, the Menu/back responder chain. Root cause not isolated; nothing
here should be trusted as a diagnosis, only as a warning.

**Before attempting this again:** the goal (kill scroll jitter between hero buttons) still stands,
but the mechanism needs to keep hero and scroll in one connected focus/view graph. Candidates worth
trying, cheapest first:
- Keep hero as a scroll item (as reverted) but neutralize the specific jitter some other way — e.g.
  check whether it is `.containerRelativeFrame` + the buttons' own focus-scale transform momentarily
  exceeding the viewport that triggers the system's bring-into-view pass, and constrain that instead
  of restructuring the tree.
- If extraction is still wanted, keep hero and the scroll content as declared siblings under a
  *shared* `.focusSection()`/`.focusScope()` rather than bare `ZStack` layering, and verify each
  directional case (Down into a show, Down into a movie, Up from every section, Menu from every
  state) individually on-device before moving on.
- Do not layer phase 2 (or anything else) on an unverified structural change again — build success
  proved nothing here.

Phase 0's fix (continuous `washProgress` scrub) is unaffected by the revert and stays in.

### Root cause found, same day — the actual detail-page focus bug

Not phase 1's fault. Verified live via Device Hub (arrow keys + Return really do drive the
simulator — `AGENTS.md` § Driving the remote was right, just untried until now).

`MediaItemFocusTarget` had **one shared case, `heroOther`, bound by six different sibling views**
(watchlist, bookmark, watched, trailer, more — plus the non-tvOS plot branch) via
`.focused($focus, equals: .heroOther)`. Multiple views sharing one `@FocusState` equals-value is
ambiguous — the engine cannot resolve which one is actually focused. On-device this showed as:

- Focus frozen dead on Play. Not "too granular," not "movies only" — **Right and Down both did
  nothing**, tested on a sparse title AND a fully-populated one (Masters of the Universe: real
  cast, ratings, genres). Data completeness was never the variable.
- **Menu closed the app instead of popping** — one press from the detail page went straight past
  the tab's own grid to the system Springboard. Confused focus state plausibly confuses the
  NavigationStack's back-context too.
- Series "worked" only because `SeasonsRailView`'s own episode cells never touched the shared
  `heroOther` case, giving focus *somewhere* legitimate to land — not because the underlying bug
  was series-specific.

Fixed: gave every button its own case (`watchlist`, `bookmark`, `watched`, `trailer`, `more`) —
[MediaItemView.swift:17](../../../KinoPubAppleClient/Views/MediaItem/MediaItemView.swift:17),
[MediaItemHeroView.swift](../../../KinoPubAppleClient/Views/MediaItem/Subviews/MediaItemHeroView.swift).
Confirmed live: Down now walks hero → Ratings → Cast & Crew → Information cleanly (with the
material wash fading in as it goes), Up walks back and restores the sharp hero exactly, Menu pops
to the tab grid instead of exiting. This likely explains several other reports from the same
session (erratic mid-scroll stops, "empty footer" with episodes not visible) — those read like
downstream symptoms of the same frozen/ambiguous focus, not separate bugs; re-verify before
assuming they still need independent fixes.

**Was already flagged and unfixed** — `01-foundation` § Focus, navigation, chrome carried
`- [ ] MediaItemHeroView — four buttons share .focused($focus, equals: .heroOther)` for a while
before this. Lesson recorded as a project decision in
[focus-and-tvui](../../../.claude/skills/tvos-surface/SKILL.md): a known-bad pattern sitting in a checklist
as a "someday" item, instead of being fixed on sight, cost a whole misdiagnosed detour (phase 1's
revert) before it was found.

### Shipped alongside, same day — not phase-numbered

Found during the phase 1 on-device pass; both landed, neither depends on phase 1.

- [x] **Library sidebar (macOS/tvOS) no longer traps detail pages beside itself.**
  `LibraryShellView`'s `NavigationStack` wrapped only the detail pane, sibling to the permanent
  sidebar; moved to wrap sidebar + detail together, matching every other tab. See CHANGELOG.
- [x] **`titleScrim` added** — Rivulet's diagonal bottom-leading→top-trailing scrim, adapted (not
  copied: their hero text is one narrow column, ours runs full width, so the existing full-width
  `bottomScrim` stays and this only adds weight over the title block). Visual tuning not yet
  confirmed on-device.
- [x] **Tab bar no longer explicitly hidden on the detail page** — removed
  `.toolbar(.hidden, for: .tabBar)` from `MediaItemView` (tvOS/iOS). iOS/iPad `TabView`s also got
  `.tabBarMinimizeBehavior(.never)`. **Honest limit:** that modifier's `.never` case is
  `@available(iOS 26.0, *)` and explicitly `unavailable` on tvOS/macOS in the 27.0 SDK — there is no
  API lever to stop the system's own scroll-driven minimize there. Confirmed live: the bar shows at
  rest on the detail page now (matches every other screen) but still recedes once you scroll into
  sections, same as it already does on Home/catalog scrolling. That's consistent, not the reported
  "random," but it is not literally pinned-through-scroll on tvOS — Apple doesn't expose that yet.
- [x] **Shadows removed from tvOS cards/badges/action buttons** — gated `#if !os(tvOS)` across
  `MediaCardView`, `HomeBannerCardView`, `PosterStyle`, `MediaActionButtonStyle` (Play pill + circle
  buttons), and `PortraitButtonStyle` (cast/crew circles — this one's `radius` *animated* with focus,
  the most expensive shape of this bug). Explicitly not touched: `heroTextShadow` (one static text
  shadow per page, not per-card, already perf-conscious per its own comment) and `HudToast` (flagged
  elsewhere for a full rewrite, not a patch). Restyle later, per the user — this pass is removal
  only, no replacement chrome added.

### Phase 2 — overlay header (tvOS + iOS + macOS)

**User called this out again 2026-08-09 as still-missing vs Rivulet: "логотип еще забыли."** It is
the one structural Rivulet feature we have not started, and the user rates the header logo as
"топ, то что надо". Raise its priority accordingly — it is wanted ahead of phase 5, and it is the
most visible single difference from the reference app that remains.

- [ ] Small title logo pinned at the top, opacity driven by scroll progress, starting **after** the
      hero metadata has cleared. Source already exists: `titleLogoURL`
      ([MediaItemHeroView.swift:415](../../../KinoPubAppleClient/Views/MediaItem/Subviews/MediaItemHeroView.swift:415)).
- [ ] tvOS: season rail moves from the scroll flow into the overlay, translating with the content
      until its rest position, then riding up with it.
- [ ] iOS/macOS: same product idea through the system — inline nav title / window title swapping to
      the logo. No custom bar.

### Phase 3 — sections as data

- [ ] A `DetailSection` list (kind + payload) replacing the hand-written `VStack`; empty sections
      simply absent, order defined in one place, shared across platforms.
- [ ] "Related" renders through the same shelf component Home uses (now honest in narrow containers
      after the `ShelfMetrics` tvOS fix).
- [ ] Information block gets its full-width band as a section background.
- [ ] Empty/error section with a focusable Retry.

### Phase 4 — row landing (tvOS only, only if needed)

- [ ] `ScrollViewReader` + `@FocusState` change → `scrollTo(anchor:)`: first row under the header,
      others centred.
- [ ] If that cannot hold the landing or stay in step with the material scrub, port the section
      list to `UICollectionViewCompositionalLayout` — we already have the bridge shape in
      [`TVUIKitMediaCollection`](../../../Packages/KinoPubUI/Sources/KinoPubUI/Components/TVUIKit/TVUIKitMediaCollection.swift).

### Phase 3.5 — typography audit (folds into phase 3)

Checked while reading the reference: its detail page has **zero** `preferredFont(forTextStyle:)` /
`UIFontMetrics` calls — every label is `.systemFont(ofSize:weight:)`, San Francisco but not
Dynamic-Type-tracking. Good proportions, same tech debt as ours; not a "system fonts, take as-is"
case. Do not port the point values.

Our own detail views have the matching mess: 36 raw `.system(size:...)` declarations across
`MediaItemDetailSections.swift` and `SeasonsRailView.swift` (cast name/role, info-panel headers,
rating tile value/title, season tab labels, debug footer) that never went through `TypeScale`,
sitting next to tokens (`ratingBadge`, `ratingAggregate`, `detailBody`) that already made the same
trip. One duplicate confirmed: `MediaItemRatingsSection.valueFont` (48/32pt rounded bold, for the
IMDb/Kinopoisk score digits) is a second "big rating number" style independent of
`TypeScale.ratingAggregate`, which exists for exactly that job.

- [ ] Inventory the 36 sites, group by role (section header, tile value, tile caption, cast
      name/role, season tab, debug footer).
- [ ] For each group, add or reuse a `TypeScale` token — nearest system text style, same method the
      `ratingBadge` / `ratingAggregate` doc comments already used ("nearest text style to the old
      fixed point size... so it now tracks Dynamic Type instead of sitting still").
- [ ] Resolve the `MediaItemRatingsSection.valueFont` / `TypeScale.ratingAggregate` duplication —
      one token, one call site pattern, not two.
- [ ] Debug footer (2353–2361: monospaced 48/30/28pt block) is diagnostic-only — confirm whether it
      ships to users at all before spending a token on it; delete instead if not.

### Third pass, same day — correcting the second pass's own regression

**I introduced this.** The second pass "fixed" missing focus feedback on the rating tiles and vote
buttons with `.hoverEffect(.highlight)`. That was the wrong tool and produced exactly the symptom
reported back: *only the icon* scaled, *and the icon gained a shadow*, on both the rating tiles and
the like/dislike pills. Cause is written in our own knowledge base — the tvOS system highlight
attaches to the **first `Image` in the label** — so on a tile labelled `logo + number + caption` it
lit and lifted the logo alone. The icons never had shadows of their own; the highlight drew them.

- [x] First replacement was a hand-rolled `DetailTileFocusChrome` (`scaleEffect` + `brightness` on
      the whole label). Functionally right, but the user's verdict was "не выглядит нативно" — and
      they were right. **Superseded within the hour by `.buttonStyle(.card)`**, the system card
      style, after they pointed at Apple's `DestinationVideo` sample: it uses
      `#if os(tvOS) .card #else .plain #endif` on every card and writes no focus code, fencing
      `.hoverEffect()` to iOS/visionOS. All four controls (`RatingTile`, `AggregateRatingTile`,
      `ViewsRatingTile`, vote pills) now go through `DetailTileStyle.buttonStyle`. The two that were
      focus stops rather than actions became `Button {}` — which is also how the sample makes
      everything focusable. Custom chrome deleted.
- [ ] **Not verified on-device.** The simulator's dev session expired mid-pass (app returned to the
      Device Activation screen); the user then asked me to stop launching it, as they test faster
      themselves. Builds are green on tvOS + macOS; the visual result is theirs to judge.

### Why the blur was "tied to episodes" — answered, and the wash rebuilt around sections

The `fakeSeasonsOnMovies` probe below did its job: with a fabricated season rail, movies started
blurring like series. That confirmed the wash was keyed to content, and the mechanism follows
directly from how it was computed.

**`washProgress` was `scrollOffset / 600`.** The page only ever scrolls as far as it needs to
reveal the next focusable thing. A tall season rail forces a long scroll → the wash reaches 1. A
movie's first section is the short ratings row → a short scroll → almost no wash. The blur was a
function of incidental content geometry, never of "am I in the hero or not". Same cause for the
"stepped" look: each focus move scrolled a different distance, so the wash arrived in uneven jumps.

It was also a per-frame cost: `onScrollGeometryChange` wrote `washProgress` on every scroll frame,
re-running `MediaItemView`'s body and with it **every shelf below**, including
`updateUIViewController` on each `TVUIKitMediaCollection`. That is the most likely explanation for
the reported scroll lag, and a strong suspect for the stranded-poster focus bug (UIKit cells
churning underneath a live focus animation).

**Rebuilt to the user's model — the section is the unit:**

- [x] `washProgress` and `onScrollGeometryChange` deleted outright. `effectiveWash` is now
      `isHeroOnScreen ? 0 : 1` and `chromeAlpha` is `isHeroOnScreen ? 1 : 0.35` — one state, one
      `.animation(value: isHeroOnScreen)` clock, identical whichever section you came from and
      whatever the title contains.
- [x] `isHeroOnScreen` is written by exactly two things: focus landing on any hero control (the
      hero section is current) and any content section reporting focus via `leaveHero`.
- [x] `.detailFocusSection()` added to every content section that did not already declare one
      (vote, cast, awards, photos, similar, both person shelves, info columns). The ratings row and
      `SeasonsRailView` build their own internally and were left alone rather than nested.
- [ ] **Unverified.** Builds green on tvOS + macOS; the user tests. Open question this does *not*
      answer: whether losing the continuous scrub is a downgrade against the original
      Rivulet-parity goal. Rivulet can scrub continuously because it drives its own scroll with a
      known geometry; ours was reading an incidental one. If continuous is wanted back later it has
      to come from a deterministic driver, not from `scrollOffset`.

### Temporary diagnostic added — `FeatureFlags.fakeSeasonsOnMovies` (DELETE ME)

At the user's request, to test their hypothesis that the blur/scroll choreography only half-works
*because* a season rail happens to sit directly under the hero, and falls apart for movies without
one. DEBUG-only flag, currently **on**, that synthesises one season of six unplayable episodes onto
any title lacking real ones (`MediaItemView.probeSeason`). Reuses the title's own artwork so the
rail renders at realistic size, and seeds two watched / one mid-progress episodes so the rail's
state chrome is exercised. Episodes carry no `files` — this is a layout and focus probe, not
playable content.

- [ ] Delete the flag, `seasonsForDisplay` and `probeSeason` once the question is answered.

**Hero scrim: it was never missing, it was half-strength.** Rather than the requested
crank-to-opaque probe (blocked by the same logout), compared the numbers directly against the
reference, which is more precise anyway. Rivulet's `ScrimGradientView`: `0.92 → 0.55 → clear` at
stops `0 / 0.45 / 1`, bottom-leading → top-trailing. Ours shipped at `0.5 → 0.18 → clear` on
`0 / 0.5 / 1` — about **half** the darkness at the anchor and a **third** at the midpoint, which
over a bright backdrop genuinely reads as nothing. `titleScrim` now matches Rivulet's values.

### Shipped, second on-device pass, same day (2026-08-09)

Found and fixed live via Device Hub, on top of the `heroOther` focus fix above:

- [x] Hero title-logo drop shadow removed
      ([MediaItemHeroView.swift:1259](../../../KinoPubAppleClient/Views/MediaItem/Subviews/MediaItemHeroView.swift:1259)
      — `heroTextShadow()` is now a no-op). Confirmed on-device: synopsis/credits over the bright
      part of a backdrop still read fine off `bottomScrim`/`titleScrim` alone. **Contrast, not
      shadow, is the standing rule now** — white text over a scrim-darkened backdrop, no per-glyph
      shadow chasing it. The proper version (measure contrast, don't just eyeball one backdrop) is
      phase 5 below, not done.
- [x] `RatingTile` / `AggregateRatingTile` / `ViewsRatingTile` had **no tvOS focus feedback at all**
      — the custom `RatingTileButtonStyle` only read `isPressed`, never `isFocused`. Replaced with
      `.buttonStyle(.borderless)` + explicit `.hoverEffect(.highlight)` (the same combination
      `focus-and-tvui.md` already prescribes for asymmetric labels) on all three. Confirmed
      on-device: the IMDb tile visibly lights up on focus now; before, both tiles looked identical
      focused or not.
- [x] Like/dislike vote buttons: the system's `.borderless` highlight was scoping itself to the SF
      Symbol inside the label rather than the whole capsule (icon + count) — same "attaches to the
      first Image" quirk documented for asymmetric labels — plus the row reserved no
      `Metrics.focusPadding`, so a focus-scaled capsule had nowhere to grow without clipping against
      the section above/below it. Added explicit `.hoverEffect(.highlight)` and the padding.
      **Not cleanly confirmed on-device** — this pass's remote-timing was unreliable enough
      (queued key presses landing late, window resizing between screenshots) that focus could not
      be pinned precisely on this one row for a before/after; the fix follows the same reasoning
      that worked for the rating tiles, but re-verify before trusting it fully.
- [x] Tab bar shown at rest on the detail page again (see phase 1's "shipped alongside" entry from
      earlier the same day) — re-confirmed still working after this pass's changes.

### Backdrop should be one image blurring, not two images cross-fading — flagged, not fixed

User's observation, 2026-08-09: the tvOS backdrop is architecturally wrong versus Apple's own
approach. It should be **one** wide still that progressively blurs as a *material* when refocusing
into below-fold sections — not a second, different asset (the small 120×180 poster raster,
independently blurred) cross-fading in underneath at rising opacity. `MediaItemHeroBackdrop`
currently layers exactly that: `blurredPoster` (always-on, blurs a *different, tiny* image) plus
`heroStill` (the real wide still, faded by `1 - effectiveWash`) plus a `.regularMaterial` rectangle
on top. Because the blurred layer is a different image than the sharp one, their colors visibly
disagree once cross-fading is under way — the user's reported "different colors."

Not fixed this session — it is a rendering-pipeline change I cannot verify without a device, and the
user asked not to launch the simulator this pass ("я быстрее тесчу бро не запускай отвлекаешь").
Recorded for the next visual pass:

- [ ] Replace the two-asset cross-fade with one wide still that is itself variably blurred
      (`UIVisualEffectView` + paused `UIViewPropertyAnimator`, the same mechanism already decided
      for the material scrub in phase 3 §3 — reuse it here instead of a second technique) driven by
      `isHeroOnScreen`.
- [ ] `blurredPoster`'s only remaining job (an always-on cheap wash under a slow-loading still) may
      still be worth keeping as the *placeholder*, but it must not be the thing that's visible once
      the real backdrop should be blurring — right now it doubles as both, which is the bug.

### Bugs found, deliberately NOT fixed — recorded per explicit instruction, tvOS

**Multiple posters stranded focused/parallaxing at once in the person shelves ("More with…",
"More from…").** Predates this session's work — reported as arriving with the TVUIKit poster
conversion. Symptom: several covers look focused simultaneously and keep parallax-wiggling with the
remote; the leading card clips its focus growth; cards to one side read selected while the other
side does not.

**This exact failure is documented in the reference app's own source**, in the comment on their
`PosterCell.resetStaleFocusAppearance()`: *"TVPosterView owns its focus scale and the remote-tilt
motion effects; both are torn down by its own coordinated unfocus animation, which sometimes never
runs (e.g. focus left the whole collection into a presented carousel) — the poster strands enlarged
AND keeps parallax-wiggling with the remote while the engine reports it unfocused, so no further
event will fix it."* We already carry the same workaround (`TVUIKitPosterCell.resetStaleFocusAppearance`,
called from `prepareForReuse` and the unfocus completion), and our `didUpdateFocus` is
near-identical to theirs — so the workaround exists but is not firing in our situation.

Difference worth investigating first: the detail page hosts **several** `TVUIKitMediaCollection`
instances at once (Similar, More from Director, More with Actor), where Rivulet's shelves live in
one collection. Focus crossing *between* sibling collections is the case their comment calls out as
unreliable. Also suspect: `MediaItemView`'s `washProgress` updates every scroll frame, re-running
`updateUIViewController` on every shelf — check whether that path can `reloadData()` mid-focus.

**Do not blind-fix this.** It is a UIKit focus-timing bug of exactly the class that caused the
phase 1 revert, and it cannot be diagnosed without running the app and watching the transition.

**Tab bar hides when returning from the detail page, leaving blank space where it was.**
Scroll down in details, the bar correctly stays put and gets covered by content scrolling over it
("lol ok fine" — that part is correct). But going back (Menu) to a screen like Library leaves the
top of the page **empty where the tab bar should be** — it does not reliably reappear. Likely a
toolbar-visibility state carried over incorrectly across the pop, not something this session's
`.toolbar(.hidden, for: .tabBar)` removal fully accounts for. Separately, on Library / Movies /
Series / Search the tab bar is presently **pinned and non-scrolling** (small clip/scoot on scroll)
— matching neither "always fixed" nor "content covers it."

**User's proposed direction, not decided:** stop treating the tab bar as chrome that
independently shows/hides/fades at all. Apple's own tvOS apps don't duplicate a separate tab-bar
layer over content — the bar **is** page content at the top; scrolled-up content simply draws over
it, the same relationship the hero already has with sections scrolling over it. That would mean:
no `.toolbar(.hidden, ...)` anywhere, no `tabBarMinimizeBehavior`, the bar just sits at the top of
whatever `ScrollView`/`TabView` content and gets covered like everything else. Whether that's
cheaper than chasing the current hide/show state bugs individually is an open question — flagged,
not answered. Don't attempt either direction blind; this needs its own focused pass with visual
iteration, not folded into whatever else is being fixed at the time.

**Episode rail leading card is wrong, and season pills steal default focus.** The episode rail's
first (leading) card should be whichever episode the Play button targets — the resume point / next
unwatched — not simply chronological-first. Right now it can even open onto the wrong **season**.
Separately: the season-pill bar should never take default/entry focus — Down from hero should land
straight on the episode rail; the pills should only become reachable via a deliberate Up from
there. **Hypothesis, not confirmed:** these two are probably one bug, not two — likely the same
reason Rivulet's version has **no header** on this row until it takes focus (ours always shows one)
— something is deciding "season pills / this row's header" is the default landing spot instead of
deferring to the actual episode. Investigate together before fixing either separately.

### Phase 4.5 — hero restore should read as instant, not animated

**Root cause found and fixed 2026-08-09 — one of the two races, not both.** There were genuinely
**two** independent writers racing the same `washProgress` state: `.onChange(of: focus)` sets it to
0 the instant focus lands on a hero button, but the `ScrollView`'s own bring-into-view scroll is
often still mid-flight, so `onScrollGeometryChange` kept overwriting it with the real (still > 0)
scroll offset for the next several frames.

`MediaItemHeroBackdrop.effectiveWash` already had the guard for this (`if isHeroOnScreen { return 0
}`, pre-existing) — but `MediaItemHeroView.chromeAlpha` (the title/synopsis/button opacity) read raw
`washProgress` directly, **no guard at all**. So the backdrop material stayed correctly pinned sharp
throughout a return, while the foreground chrome kept re-dimming and re-brightening in step with the
stray scroll-driven writes — that mismatch is what read as "still translucent, blur moves in janky
steps." Fixed by giving `chromeAlpha` the same `isHeroOnScreen` guard
([MediaItemHeroView.swift:472](../../../KinoPubAppleClient/Views/MediaItem/Subviews/MediaItemHeroView.swift:472)).

- [x] Guard added; confirmed on-device that Up → hero navigation still works end-to-end
      (focus reaches Play, then the button row, then back down through Ratings/Cast, Menu still
      pops correctly) — no regression from the change.
- [ ] **Not confirmed:** whether the visible jank is actually gone. A static screenshot cannot show
      animation smoothness — this needs eyes on the real transition, not a screenshot diff. The
      *reasoning* is solid (the race is real, the fix mirrors an already-correct sibling pattern in
      the same file) but treat it as unverified until someone watches it happen.
- [ ] The underlying race (two writers to one `washProgress`) is still there, just now harmless at
      both known consumers. A future consumer of raw `washProgress` would hit the same bug again —
      consider fixing the write side too (e.g. don't let `onScrollGeometryChange` overwrite while a
      focus-driven return is in flight) rather than guarding every reader individually.

### Phase 5 — contrast over shadow — **LAST PRIORITY, park it**

**Explicitly deprioritized by the user 2026-08-09: do this last, after the UI itself works.**
Reasoning given: for MVP the artwork here may be dropped entirely in favour of plain labels, so
tuning a luminance-adaptive scrim is work that may be thrown away — "не актуально заниматься такой
хуйнёй когда юай не сделан нормально." Leave as a TODO against the page as a whole; do not pick it
up ahead of the focus/blur/structure phases.

- [ ] Replace the one-backdrop eyeball check with an actual contrast rule: text needs to read over
      *any* backdrop color, not just the one tested live. Likely needs the scrim's darkness to
      respond to the backdrop's own luminance rather than being fixed constants.
- [ ] Audit every other per-glyph/per-card shadow this session removed for whether it was covering
      for insufficient contrast elsewhere, now that they're gone.
- [ ] Open product question that may delete this phase outright: does the MVP keep hero artwork at
      all, or fall back to labels? Answer this before spending time here.

### Phase 6 — tvOS sections: no iOS/macOS-style chevron headers

**Project decision, not yet applied:** on tvOS, a section header that itself navigates (chevron →
push to a full list, the `SectionHeader(showsChevron:)` + `NavigationLink` pattern
`MediaPosterShelf` uses today) should not exist. "See more" on tvOS is either a trailing card at the
end of the row, or a trailing button in the row — never a separately-focusable header link, which
reads as an iOS/macOS affordance transplanted somewhere the remote doesn't support it naturally.

- [ ] Inventory every tvOS section header that currently navigates (`MediaPosterShelf` and anything
      built the same way).
- [ ] Replace with a trailing "More" card/button inside the row's own horizontal scroll.

### Phase 7 — Information block: real focus sections, not per-link focus

The Information / Languages / Technical columns currently let **individual genre links** (and
presumably other individual values) become focus stops on their own — spatial Down/Up wanders
through them one at a time. Should instead be three `.focusSection()` groups (one per column),
focused as a whole or by their own logical sub-groups, not link-by-link.

- [ ] Group each of the three columns under its own `.focusSection()`.
- [ ] Add a centered "scroll to top" button below this block as a guaranteed focus anchor at the
      true bottom of the page — doubles as fixing the "dead end at the bottom" class of bug and
      matches the Apple TV app's own convention of ending a detail page with one.
- [ ] Rivulet's stacked vertical rating-style cards (their `AboutInfoCells.swift` "Information /
      Languages / Accessibility" columns) read better than our current layout — recompose genres /
      countries / rating / audio / subtitles etc. into that shape. Visual pass, needs iteration, not
      a blind port.

### Phase 8 — port Rivulet's round-button info popup, all platforms

**Not tvOS-only.** The user's words: "у нас кошмар" (ours is a nightmare) applies everywhere. Steal
the *pattern* (round icon button → focused popup with the extended info) from Rivulet's
`InfoPopupViewController`, not the code (PolyForm Noncommercial — technique only, per
[community-fork](../../community-fork.md)), and land it as one shared component across tvOS/iOS/macOS
rather than three divergent implementations.

- [x] **Landed 2026-08-11, with the trigger deliberately changed.** `InfoPopup` in KinoPubUI is the
      one shared component (`expandsIntoInfoPopup(title:)`), and it is **not** hung off a round icon
      button the way `InfoPopupViewController` is. User decision: the clipped content is the
      trigger. The synopsis opens itself — now on *every* platform and *regardless of truncation*,
      where before it was a dead press on tvOS whenever the text happened to fit and plain
      unfocusable copy off tvOS. The About columns (`AboutColumn`, `AboutLegendColumn`) open
      themselves too, which is what "внизу на секциях" asked for and what gives the bottom of the
      page real focus stops.
- [x] It replaced exactly one thing: the private `MediaItemDetailSheet` / `MediaItemSheetLayout`
      pair inside `MediaItemDetailSections.swift`, whose own doc comment already promised "the
      synopsis, **or a column with its lists unclamped**" and only ever did the synopsis. Deleted.
- [ ] **Open, needs judging on device:** the About columns are now `Button`s, so on tvOS they wear
      `.card` — which argues with `AboutLayoutAppleShape`'s "no card behind the columns at all,
      their job is to be skippable". Either the note gives (a column you can open is a control) or
      the columns need a quieter focus treatment that is still system-drawn. Do not hand-roll one.

### Phase 9 — KinoPub rating card (likes/dislikes/views merged)

Raised alongside the like/dislike focus-crop fix above, but a separate, larger change — not done
this pass. Likes/dislikes/views should stop being their own row and become a fourth tile in the
Ratings row, styled like the IMDb/Kinopoisk tiles: icons for like/dislike inside the card, view
count alongside. Clicking the card is where asking the user for *their* rating would live —
currently that flow doesn't exist and the row reads as cluttered ("щас чересчур" — right now it's
too much). Needs its own design pass — what the card shows before a vote vs. after, what clicking
it actually opens — before touching `MediaItemCommunityVoteSection`.

### Deferred

- Two focus stops per episode card (point 10) — decide the product question first; the race guards
  it drags in are the reference app's least attractive code.
- Anything touching the preview carousel.

## Open questions

- Does the material scrub survive on A12-class boxes? `DevicePower.isLowPowerAppleTV` already gates
  glass over video; a full-screen scrubbed `UIVisualEffectView` needs the same scrutiny.
- Fixed geometry: their constants (`topBand 230`, reserve 600, section heights 435/318/370/460) are
  dialed for 1080p and pre-date systemic Dynamic Type on tvOS 26+. Ours must derive from the
  container, the same way `ShelfMetrics` now does.

## TVUIKit component gallery — added 2026-08-09

New DEBUG/tvOS-only page: `KinoPubAppleClient/Views/UILab/TVUIKitComponentGalleryView.swift`.
Settings → Diagnostics → "TVUIKit Gallery" (`TVProfileSettingsView`).

Every native TVUIKit type with no SwiftUI equivalent, bare — zero custom focus/scale/highlight code
anywhere on the page, so whatever motion and chrome appears is entirely system-owned: `TVCardView`,
`TVPosterView`, `TVCaptionButtonView`, a bare `TVLockupView` (header/footer +
`TVLockupViewComponent` conformance on the content box, so one row shows a component reacting to
lockup state vs. the system's own automatic motion), `TVMediaItemContentConfiguration` (badges —
default and live-content style — plus `playbackProgress`, hosted the way Apple intends: a real
`UICollectionView` with `NSCollectionLayoutSection.orthogonalLayoutSectionForMediaItems()`, not a
standalone view), `TVMonogramContentConfiguration` (many same-shape avatars in one row, to see how
the focus engine behaves with a lot of identical neighbors), a rough `TVCollectionViewFullScreenLayout`
demo (explicitly labeled rough — that layout is meant to own the whole screen, not a boxed row), and
`TVDigitEntryViewController` (presented full-screen via a button, since it's a whole view controller).

Also a direct **`.focusSection()` comparison**: the same two short rows laid out twice, once merged
into one `.focusSection()` and once as two separate adjacent ones, side by side — Up/Down between
them should show directly whether merging changes behavior, which is the open question behind
several of today's other findings (hero-as-one-section, stranded-poster focus).

**Real API surface note for future TVUIKit work:** `TVMediaItemContentConfiguration` and
`TVMonogramContentConfiguration` are `NS_REFINED_FOR_SWIFT` — in Swift they are **structs**, not the
classes the ObjC headers declare, and their factory methods are shorter than the header names
suggest: `TVMediaItemContentConfiguration.wideCell()` (not `wideCellConfiguration()`),
`TVMonogramContentConfiguration.cell()` (not `cellConfiguration()`), badge properties live at
`TVMediaItemContentConfiguration.BadgeProperties.default()` / `.liveContent()` (not a top-level
`TVMediaItemContentBadgeProperties` type), and `TVLockupViewComponent`'s method is
`updateAppearance(forLockupViewState:)`, not the ObjC-literal `updateAppearanceForLockupViewState:`.
None of this is discoverable from the headers alone — found by compiling single-line probes against
the SDK directly (`swiftc -typecheck`) rather than guessing through full app rebuilds.

Compiles on tvOS + macOS. **Not run** — the user is testing locally and asked not to launch the
simulator this pass.

---

## 2026-08-10 — the fold was rebuilt on Apple's guidance, and it is still wrong

Second day on this page. Apple's tvOS layout guide ("Show content above and below the
fold") turned out to describe almost exactly this screen, and we had hand-rolled four
things it documents. Those were replaced (see below). **The fold still does not work,
and the reason is a mistake in how I read the guide** — recorded here in full so the
next session starts from the correct diagnosis rather than from "it's done".

### What was replaced with the documented mechanism

| Hand-rolled | Replaced by | Deleted |
| --- | --- | --- |
| `isHeroOnScreen` inferred from per-section focus reporters | `.onScrollVisibilityChange(threshold: 0.5)` on the hero | `leaveHero` writes, second writer |
| `scrollTo` driver on two anchors | custom `ScrollTargetBehavior` (`MediaItemFoldSnappingBehavior`) | `MediaItemHeroScrollDriver` |
| `UIVisualEffectView` bridge for the wash | `.regularMaterial` masked by a `LinearGradient`, stop opacities animate | `MediaItemHeroMaterialBackdrop`, `HeroMaterialBackdropView` |
| `ExpandableButtonStyle` (custom focus/hover) | `.card` via `DetailTileStyle.buttonStyle` | `ExpandableButtonStyle`, `ExpandableLabel` |

Hero is now `containerRelativeFrame(.vertical, alignment: .topLeading) { l, _ in l * 0.8 }`
with a full-width `.focusSection()` — the guide names that focus section explicitly:
without it "moving focus up from the right side of the shelves below might fail, or
might jump all the way to the tab bar", which is verbatim the Up-from-sections bug this
page carried for weeks.

Also corrected: I had claimed SwiftUI cannot animate a material and moved it to UIKit.
It can — you animate the **mask** in front of the material, not the material. Never
fade a material with `.opacity()`; that draws the full-strength effect
semi-transparently instead of weakening it.

### The mistake: the snap does not apply to focus-driven movement

`ScrollTargetBehavior.updateTarget` is consulted when a scroll has a *target* — swipe
deceleration, programmatic `scrollTo`. Apple's fold-snapping sample is for a landing
page that the user **swipes**. This page does not move by swiping: it moves because
the **focus engine** scrolls just far enough to reveal whatever element took focus.
That path never asks the behaviour anything, so nothing snaps.

Observed consequence, on device:

- Focusing the season tab flips the fold flag (`onScrollVisibilityChange` fires on any
  scroll, including a 50pt nudge), so the backdrop darkens and blurs…
- …but **the page does not move**. The hero neither lifts nor leaves. Nothing below
  rises. Two states exist for the *background* and not for the *layout*.
- The overlay title logo rides the same flag, so it appears instantly on that same
  micro-scroll — far too early.

This is the same conclusion the plan already reached about Rivulet and then filed
under "not ported": they set `isScrollEnabled = false` and drive `contentOffset` from
a `CADisplayLink` **because the focus engine's own scroll animator has to be replaced,
not corrected**. I read that as heavyweight and proposed a lighter version; the light
version leaves the engine in charge, which is the whole problem. Plozz reaches the
same shape from the other side: its hero recede is an explicit point value
(`recedeLift`) passed in and animated by the view itself, with a note that the offset
must be applied *before* `.ignoresSafeArea()` or the safe-area breakout silently
cancels it.

**So: the fold needs a deterministic position driver.** The page knows both numbers
(0 and the hero height); on a polarity change it must set the offset itself rather
than ask the engine to reveal something. Re-file the "hand-driven scroll" line in this
plan from *rejected* to *required*.

### Shelf semantics — separate bugs, none of them caused by the fold

Reported on device, all correct, none fixed:

- **A shelf's header appears on focus.** Apple TV shows a slice of the shelf peeking
  with no title; the title arrives when the shelf takes focus. Ours shows the title
  permanently. `SeasonsRailView` already has `showsChrome` for exactly this and is
  passed `true` unconditionally.
- **One season → the tab strip must not be focusable at all.** Down from the hero
  should land on an episode. Even with twenty seasons, the tabs are reached **only**
  by pressing Up from an episode — never on the way down.
- **The selected season tab stays lit after focus leaves.** Not stranded focus:
  `SeasonTabButtonStyle` colours its text on `isSelected || isFocused` while only the
  plate depends on `isFocused`, so the selected tab is permanently bright and reads as
  still-focused. Selection must be quieter than focus.

These three are independent of the fold and can be fixed first; they account for much
of the "everything is dark but focused and it's mush" impression.

### Order for the next session

1. Shelf semantics (three items above) — cheap, independent, removes most of the noise.
2. Deterministic fold driver — replace the engine's scroll rather than correct it.
3. Only then re-judge the overlay logo timing, which is downstream of 2.



---

## 2026-08-10 — the fold, corrected twice

### What was wrong with my first explanation

I told the user `ScrollTargetBehavior` does not apply to focus-driven movement, and
that the fold therefore needed a hand-driven `contentOffset`. **That was wrong**, and
their own observation disproved it: the snap worked correctly for the ratings section
(below the episodes) while doing nothing for the season rail.

The real cause is the guards copied verbatim from Apple's landing-page sample:

```swift
if aboveFold, target.rect.minY < showcaseHeight * 0.3 { return }
```

With an 864pt showcase that threshold is ~259pt. The season rail is *already peeking*
under the hero, so focusing it scrolls ~100pt — inside the leave-it-alone zone, so no
snap. Ratings sit far enough down to clear the threshold, so they snapped. Those
guards exist for a page the user **swipes** ("they barely moved, don't yank it"). On a
page that moves by **focus**, the first thing below the fold is always a short scroll
away, so the guard fires every time.

### The model that is actually right

The user stated it plainly and it is correct: *the fold is a property of which page
owns focus, not of how far the page happened to scroll.* Focus in the hero → offset 0.
Focus anywhere below → offset = showcase height. No thresholds, no distance maths.

Fixed accordingly:
- `MediaItemFoldSnappingBehavior` now snaps unconditionally on `aboveFold`.
- `aboveFold` comes from **focus**, not `onScrollVisibilityChange`. Deriving it from
  scroll visibility was circular on this page: the scroll decided the fold and the fold
  decided the scroll. `MediaItemView`'s `focus` is non-nil exactly while a hero control
  holds focus — that single value is the fold, and it has exactly one writer.
- `FocusLog.snapped(from:to:aboveFold:)` logs every snap decision. A snap that silently
  declines to fire was indistinguishable from one that never ran, which is how the
  guard bug survived a whole pass.

**Unverified on device.** Confirm: focusing the season rail moves the page a full
showcase height, and Up back to the hero returns it to 0.

### Shelf semantics — separate bugs, all still open

These are not fold problems and were not fixed:

- [ ] **Section header must appear on focus, not always.** An Apple TV shelf peeks
      from below the fold with no header; the header arrives when it takes focus.
      `SeasonsRailView.showsChrome` exists for exactly this and is passed `true`
      unconditionally.
- [ ] **One season → the tab strip must not be focusable at all.** Down from the hero
      should land on the episode. Even with twenty seasons the tabs are reachable only
      by Up *from* an episode — never on the way down.
- [x] **Selected tab looked as bright as a focused one.** `SeasonTabButtonStyle`
      coloured on `isSelected || isFocused`, so a tab you had left stayed lit and read
      as still-focused. Replaced with the stock `.buttonStyle(.borderless)`; selected
      is now `.primary` against `.secondary`, quieter than focus.
- [ ] **TODO:** replace the tab strip with a real system pill/toggle component once we
      decide which (a glass-styled equivalent exists outside tvOS worth checking).
      `.borderless` is the interim, chosen so no hand-rolled focus code remains.
- [ ] **Overlay logo appears too early** — it keys off the same fold flag, so it
      arrived on the micro-scroll. Re-check now that the fold is focus-driven.

### Standing lesson

Two passes in a row went wrong the same way: Apple's sample was copied including
constants tuned for a *different input model* (swipe), on a page driven by focus. Copy
the mechanism, re-derive the thresholds.
