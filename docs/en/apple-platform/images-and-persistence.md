# Images, persistence, and atoms

## Evergreen

- `AsyncImage` HTTP caching is documented as **27+**. On baseline 26, plan a shared custom loader /
  cache (Nuke is a common mature option — evaluate via borrow-before-build).
- Masked marquee / scrolling labels are not a system control — measure, duplicate text, mask,
  gate on focus + reduce motion (see `MarqueeText`).
- Prefer `.lineLimit` + a focusable More control that opens a sheet over expanding text in place.
- Atomic components beat copy-pasted type and badge stacks. Dynamic Type and VoiceOver need real
  labels on cards and hero actions.

## Project decisions

- Continuity policy owns stale-first rendering and card→detail image handoff —
  [data-continuity](../policies/data-continuity.md).
- `ContentStore` + disk row snapshots already cover Home/Library summary rows; paginated Movies /
  Series / Search grids and item-facts TTL extension remain open work in the foundation feature doc.
- `CachedRemoteImage` / fallback chains exist to escape `AsyncImage` grey-forever on 404s — prefer
  one pipeline, not N ad-hoc loaders.
- Cache dominant / average colours with artwork when used for banners or logo contrast.
- Search may show empty poster tiles from frame one so the remote has a focus landing zone.

## Performance notes (evergreen)

- Avoid full-screen blur identity resets on every focus move.
- `@Observable` migration helps granular invalidation but is not required for cache correctness.
- Deduplicate in-flight row refreshes; sidebar badge sync should be TTL-gated, not per tab switch.

## Candidate libraries (evaluate, don't auto-add)

| Library | Candidate use |
| --- | --- |
| Nuke | Image loading / caching / prefetch |
| Boutique | Lightweight persistence |
| ColorKit / DominantColors | Palette extraction |
| SwiftUI Introspect | Rare UIKit escape hatches |
| Pow / Wave | Interruptible / delightful motion later |
| WhatsNewKit | Release notes UI later |
