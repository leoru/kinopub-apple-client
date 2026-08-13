# 07 — Atomic UI components, typography, accessibility, images

Condensed English summary of a 2026-07-25 research pass, baseline 26.0, 27-only noted separately.
Current guidance lives in
[`.claude/skills/tvos-surface/SKILL.md`](../../../.claude/skills/apple-chrome/SKILL.md)
and [`.claude/skills/tvos-surface/SKILL.md`](../../../.claude/skills/apple-chrome/SKILL.md).
This report's accessibility checklist is the most complete one in the archive and largely predates
the a11y coverage that now exists in the codebase — treat the "what's fixed" claims here as frozen
at 2026-07-25, not current status. Russian original: `07-ui-components-a11y.ru.md` (gitignored,
local only).

## TL;DR (at the time)

- **Native `AsyncImage` caching exists — but only from 27.0.** Apple's docs, verbatim: "In iOS 27,
  macOS 27, watchOS 27, tvOS 27, and visionOS 27 and later, `AsyncImage` caches downloaded image
  data following the transport protocol." At baseline 26 there is no cache — the app needed to write
  its own. (27-only extras: `init(request:scale:transaction:content:)`, `asyncImageURLSession(_:)`.)
- **There is no system-provided masked marquee text** on any platform, in 26 or 27. It has to be
  hand-built: measure via `onGeometryChange`, two text copies in an `HStack`, offset animation, a
  fixed-width `LinearGradient` edge mask, gated on `\.isFocused` (tvOS) and
  `accessibilityReduceMotion`. Apple's "…more" pattern is a *different* thing — not an ellipsis, but
  `.lineLimit(n)` plus a separate focusable control that opens the full text in a sheet. The app
  already had this right for its synopsis text; only the truncation-detection mechanism (double
  `PreferenceKey` measurement) was unnecessarily complex and simplifies to one `onGeometryChange`.
- **The app's "component library" wasn't one.** At the time, `KinoPubUI` had three files with zero
  production references (`KinoPubButtonTextStyle`, `Image+CenterCropped`, a `ToastContentView`
  literally commented out with "REPLACE IT ITS AWFUL TODO"), `Font.KinoPub` used exactly once in the
  whole project, and ~53 hard-coded `.system(size:)` calls in `Views/` plus ~40 more inside the
  components themselves.
- **Dynamic Type was broken by design**: `.system(size:)` never scales; `@ScaledMetric` had zero
  uses. Note: tvOS itself has no user-facing Dynamic Type slider (unverified at the time, but
  consistent with tvOS's accessibility settings set) — so this specific gap mattered mainly for
  iOS/iPadOS/macOS, not the primary tvOS platform.
- **VoiceOver coverage was minimal**: 9 `.accessibilityLabel` calls across the entire app, and the
  main card component (`MediaCardView`) had none — a poster would read as "image, `<title>`" with no
  rating, no progress, no "S2, E5."
- **`.badge(_:)` and `badgeProminence` are unavailable on tvOS** — the system badge mechanism isn't
  usable on the primary platform, so any 4K/HDR/CC/SDH/age badge system has to be built from scratch.
- **Half the desired badges have no backing data.** Per the app's own stream survey (20 items):
  every delivered stream is `avc1`/H.264 8-bit + `mp4a`/AAC, SDR, ≤1080p. 4K/HDR/DV/Atmos badges
  would never light up on any title. What's actually derivable: quality tier, AC3 flag, multi-audio
  count, CC/SDH via filename heuristics, a poor-quality flag. Age rating needs a third-party source
  (Kinopoisk Unofficial).
- **The system component for avatar placeholders is `TVMonogramContentView`** (TVUIKit, tvOS 15+),
  whose `personNameComponents` builds properly **localized** initials (important for Cyrillic names)
  — but it's UIKit-only and tvOS-only, so a cross-platform `AvatarView` was recommended instead,
  borrowing just the `PersonNameComponentsFormatter` idea rather than the view itself.
- **What's actually new at 26 for this topic**: `symbolVariableValueMode(_:)` and
  `symbolColorRenderingMode(_:)`. Everything else in scope (`@ScaledMetric`,
  `lineLimit(_:reservesSpace:)`, `textScale`, `TextRenderer`, `ContentUnavailableView`,
  `allowedDynamicRange`) has existed for years and simply wasn't adopted yet.

## What was available (verified against Apple's docs)

Images: `AsyncImage` (15+, uncached pre-27), `CGImageSourceCreateThumbnailAtIndex` (downsampling at
decode time — the real fix for holding a 1080×1620 bitmap in memory to show it at 200×300),
`UIImage.preparingForDisplay()` (off-main-thread forced decode), `ImageRenderer` (16+),
`allowedDynamicRange(.high)` (17+, real HDR brightness for a subtree — use sparingly, it's genuinely
bright and costs battery).

Typography: `Font.TextStyle` is the only path to Dynamic Type; `@ScaledMetric(relativeTo:)` scales
numeric values (padding, icon size) alongside it; `.lineLimit(_:reservesSpace:)` (16+) reserves
height so rows don't jump on focus change; `.textScale(_:isEnabled:)` (17+); `TextRenderer` (18+,
per-line/per-glyph custom drawing — where a genuine Apple-style edge fade would live, judged not
worth the cost here, see below).

Badges/menus: `.badge(_:)` and `BadgeProminence` are **tvOS-unavailable**; `Menu` is tvOS 17+;
Apple's own docs show title+subtitle inside a menu item as two `Text` views in one label, and
`.menuOrder(.fixed)` to stop tvOS from reordering items.

Accessibility: `\.accessibilityReduceMotion`, `\.accessibilityReduceTransparency` ("backgrounds
should not be semi-transparent; they should be opaque" — directly about `.ultraThinMaterial`
pills), `\.accessibilityDifferentiateWithoutColor` ("UI should not convey information using color
alone" — directly about rating-tier badges coded only by color),
`\.accessibilityShowBorders` (successor to the deprecated `accessibilityShowButtonShapes`, backdeployed
before tvOS 26.1). `ContentUnavailableView` (tvOS 17+) covers empty states, but its focusability on
tvOS without explicit `actions:` was flagged as needing device verification.

## What this became in the app

Accessibility coverage has grown since this pass — `accessibilityLabel`/`accessibilityElement` now
appears in `MediaCardView`, `MediaCapabilityBadgesView`, `MarqueeText`, `HomeBannerCardView`,
`MediaItemHeroView`, `MediaItemDetailSections`, and `AuthView` (per a repo-wide grep at the time of
this update) — well beyond the 9-label count this report found. `MediaCapabilityBadgesView`
suggests the badge-data-honesty finding above (don't badge 4K/HDR/Atmos without real data) was
followed. Whether the specific checklist items below (Dynamic Type scaling, Reduce Motion/
Transparency gating, `@ScaledMetric` adoption, the marquee/expandable-text/avatar/badge component
consolidation) are done is not something this archive can answer — check current code and
[`01-foundation-continuity.md`](../../../ROADMAP.md) rather than assuming
either way.

## The image cache (Question 1: is there native caching at 26/27?)

**No at 26, yes at 27** — but the 27 cache is HTTP-level (`URLCache` via transport protocol), not a
decoded-bitmap cache, and depends on the server sending proper cache headers (unverified for the
kino.pub CDN at the time). It doesn't remove repeated *decoding*, which is the actual bottleneck on
Apple TV. **Conclusion: a hand-written cache was necessary regardless of target OS version** —
two-tier (`NSCache` for decoded images + files for original bytes), decoding straight to the target
pixel size via `CGImageSourceCreateThumbnailAtIndex`, and coalescing concurrent requests for the
same URL.

Borrowed: Rivulet's `ImageCacheManager.swift` (actor-based, `NSCache` + disk LRU eviction, 2-week
TTL with stale-while-revalidate, download coalescing, two decode tiers for thumb/full, corrupt-byte
validation via `CGImageSourceGetStatus`, backoff retries on 5xx) and its thin `CachedAsyncImage.swift`
wrapper (a near drop-in `AsyncImage` replacement). Explicitly **not** borrowed: silo-apple's
Nuke/NukeUI-based cache — an extra dependency this app's small-dependency-list stance argues
against — though its device-memory-budget idea (halve the decoded-image cache size on constrained
devices via `physicalMemory <= 3.5GB`) and its `didReceiveMemoryWarningNotification` handling were
worth keeping. Thumbhash/blurhash placeholders were rejected — kino.pub's API doesn't provide a
hash, and computing one client-side would require downloading the image first, defeating the point.

## Marquee text and "…more" (Question 2)

Two genuinely different things, often conflated. **Marquee** (scrolling single-line text for names
that don't fit) has to be hand-built per the rules Apple's own tvOS media-app sample implies: scroll
only the focused/active element, only when the text actually overflows, ~2s dwell before starting
and after finishing, edge masked with a fixed-width gradient on the side that still has hidden text,
never scroll under Reduce Motion (truncate instead), and always give VoiceOver the full string via
`.accessibilityLabel` regardless of visual state. A working `MarqueeText` recipe worth preserving as
a reference: measure via `onGeometryChange` (not a `PreferenceKey` pair — cheaper), gate on
`isFocused && !reduceMotion`, mask with `HStack` of two fixed-width `LinearGradient`s rather than
`UnitPoint` stops (whose fade width otherwise drifts with container width). One landmine specific to
this app: `@Environment(\.isFocused)` is only visible to the focusable view itself — inside a
`NavigationLink`'s label it reads `false`, which is exactly why the codebase has a custom
`\.cardFocused` environment key; any new focus-reactive component inside a card label must read that
key, not `\.isFocused` directly.

**"…more"** is not a marquee — it's `.lineLimit(n)` plus a separate focusable control opening the
full text, which the app already implemented correctly for its synopsis view; only the
truncation-detection mechanism was over-engineered (double `PreferenceKey` → one `onGeometryChange`
comparing a hidden full-height copy against the clamped height). A `TextRenderer`-based genuine
last-line fade was considered and explicitly **rejected** — it disables system text-rendering
optimizations for a visual difference barely perceptible on a 10-foot screen.

## Avatar placeholders (Question 4)

`TVMonogramContentView` (TVUIKit, tvOS 15+) is the system answer — its `personNameComponents`
property builds a properly localized monogram (critical for names like "Данила Козловский" → "ДК,"
not "первые буквы через пробел"). But it's UIKit-only, tvOS-only, and has no SwiftUI wrapper, so it
would only cover one of four platforms and still need duplicating. Recommendation followed: a
cross-platform `AvatarView` built in-house, but using `PersonNameComponentsFormatter` — the actual
correct part of Apple's approach — instead of the app's original ad hoc
`name.split(separator: " ").prefix(2)` initials logic, which the app had implemented independently
in two places at the time.

## Dynamic Type / accessibility checklist (Question 5)

The most load-bearing table in this report — kept close to verbatim as a reference checklist, since
it's more complete than anything currently in policy docs:

| Risk | Where it bites | Fix |
| --- | --- | --- |
| `.system(size:)` instead of a text style | Anywhere text is set | `.font(.callout.weight(.medium))` etc. — only `TextStyle`-based fonts scale |
| Fixed-height card/button frames | Card captions, action pills | `.lineLimit(n, reservesSpace: true)` + `@ScaledMetric`, `.frame(minHeight:)` not `.frame(height:)` |
| A metadata `HStack` that doesn't fit at large sizes | "2025 · 1h 55m · Japan · IMDb 8.1"-style rows | `ViewThatFits` between a horizontal and vertical layout, or gate on `dynamicTypeSize.isAccessibilitySize` |
| Rating tier coded only by color | Any color-only status indicator | A non-color differentiator (shape/symbol), shown when `\.accessibilityDifferentiateWithoutColor` is true |
| `.ultraThinMaterial` with no Reduce Transparency branch | Pills/circles over artwork | Opaque fallback fill when `\.accessibilityReduceTransparency` |
| Animations with no Reduce Motion gate | Focus crossfades, springs, progressive blur | `.animation(reduceMotion ? nil : ..., value:)` |
| Custom `ButtonStyle`s ignoring show-borders | Any hand-rolled button chrome | Read `\.accessibilityShowBorders` in one shared chrome helper, not per style |
| Cards with no VoiceOver description | The primary card component | One `.accessibilityElement(children: .ignore)` + a composed label (title, rating, progress, episode info) |
| Progress bars with no `accessibilityValue` | Watch-progress indicators | `.accessibilityValue(Text(progress, format: .percent))` |
| Text hidden via `.opacity(0)` instead of conditional rendering | Off-focus captions | Verify VoiceOver doesn't double-read it; add `.accessibilityHidden` if needed |

Testing tools: `.environment(\.dynamicTypeSize, .accessibility5)` in previews; Accessibility
Inspector's on-device audit; Xcode's live Environment Overrides (Dynamic Type, Bold Text, Reduce
Motion, Reduce Transparency, Differentiate Without Color, Increase Contrast, VoiceOver) — no
rebuild needed. On tvOS specifically: Bold Text, Increase Contrast, Reduce Motion, Reduce
Transparency, and VoiceOver are real user settings and worth testing; Dynamic Type is not (no
user-facing slider on tvOS, unverified but consistent with tvOS's settings surface) — so on the
primary platform, motion/transparency/contrast handling matters more than font scaling.

## Badge system data honesty (Question 6)

Restated from the TL;DR: build an extensible badge model, but only *populate* kinds with real data
— `4K`/`HDR`/`DV`/`Atmos` stay defined-but-unused enum cases rather than badges nobody will ever
see. The recommended shape (a `MediaBadge` struct with `kind`/`text`/`systemImage`/
`accessibilityLabel`, factories living in the app target rather than `KinoPubUI` since a UI package
shouldn't own localization, one shared `MediaBadgeView`/`MediaBadgeRow` renderer styled via an
environment value so hero/card/list contexts can differ without forking the type) mirrors
`MediaCapabilityBadgesView`, which now exists in the codebase — consistent with, though not provable
as directly descended from, this recommendation. Borrowed from silo-apple: separating "badge
definition" from "resolve a value from data" from "render," and defensive string matching for
badge triggers (`contains("atmos")`, not equality — "Dolby TrueHD Atmos" wouldn't match an exact
string check).

## tvOS pitfalls from this report

`.clipShape`/`.clipped` on a poster kills the system focus-zoom effect — any mask (including a
marquee's gradient mask) belongs on the *caption*, never the artwork. Overlay layers stacked on a
`.borderless` poster fragment its specular highlight — a real architectural constraint against
putting badges directly on tvOS card artwork (as opposed to in the caption, or on cards that don't
use `.borderless`) — a genuine divergence from how silo-apple places corner badges. VoiceOver on
tvOS reads the label of the *focused* element, not a whole subtree — `.accessibilityElement(children:
.ignore)` plus one composed label per card is a requirement, not an optimization.
`.ultraThinMaterial` over live video is expensive for the same backdrop-resampling reason documented
in report 02/`KinoGlass` — any material pill floating over a playing hero trailer is the same class
of problem.

## Open questions this report left unverified

Whether the kino.pub image CDN sends cache-control headers (determines whether the 27-only native
`AsyncImage` cache would do anything); whether tvOS actually has a user-facing Dynamic Type control
at all; whether VoiceOver reads text hidden via `.opacity(0)`; whether `ContentUnavailableView`
without explicit `actions:` remains focusable on tvOS; exact SF Symbol names for prospective badges
(verify in the SF Symbols app, don't guess); how a two-`Text` menu item (title + subtitle) actually
renders on tvOS vs. the iOS screenshots in Apple's docs; the real on-device visual/perceptual cost of
`allowedDynamicRange(.high)`; and the actual performance cost of a marquee re-triggering across a
20-card row on A12-class hardware — flagged as an Instruments question, not measured here.
