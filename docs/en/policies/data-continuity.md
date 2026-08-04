# Data continuity

Durable policy for local state, images, and loading. Related how-tos:
[`docs/en/apple-platform/images-and-persistence.md`](../apple-platform/images-and-persistence.md).

## Priority order

1. **Instant continuity** — returning to a tab, list position, or previously opened title shows the
   last known good state immediately.
2. **Card → detail handoff** — pass the known `MediaItem` / card model, already-loaded poster or wide
   artwork handle, and cached palette into the destination. Detail paints from that snapshot and
   enriches missing fields; it must not blank-reload everything the card already had.
3. **Deduplicated fetches** — identical URLs and detail requests share in-flight work. Stale cache
   paints first; revalidation runs underneath.
4. **Prefetch on intent** — wide artwork and likely next detail payloads may prefetch on focus /
   hover / imminent navigation.
5. **Exact skeleton** — only when there is no usable cache (true cold load), and only if it matches
   final geometry.
6. **Delayed spinner** — for indeterminate waits where a skeleton does not orient the user.
7. **Distinct error** — never reuse eternal grey as both loading and failure.

## Local persistence

- Prefer one coherent store ownership model for list rows, item facts, image metadata / palette, and
  freshness (TTL + stale-while-revalidate). Do not invent a third cache beside `ContentStore` /
  `MetadataCache` / the image pipeline without consolidating.
- Local optimistic writes (hide, watched, bookmark) are authoritative until the server contradicts them.
- tvOS may have weaker durable disk than iOS/macOS — longer in-memory TTLs are acceptable; do not
  pretend full offline parity exists if it does not.
- "Do not re-request what we already know" applies to metadata the user recently viewed **and** to
  artwork already decoded for a transition.

## Images and visual intelligence

- One shared image loader / cache path for posters, wides, logos, and cast photos.
- Fallback chain for artwork sizes (wide → big → medium, etc.) with explicit failure states.
- Cache average / dominant palette with the image metadata when useful for banners, title logos, or
  legibility — do not recompute in every view.
- Adaptive / variable blur and system vibrancy / foreground styles come before hand-rolled contrast
  heuristics. Custom light/dark sampling is allowed for content artwork when system materials cannot
  decide (banner overlays, title logos).
- Zoom / matched transitions should carry the same image identity the card already showed.

## Skeletons (corrected policy)

Skeletons are **not banned**. Abstract grey stand-ins that jump when real content arrives **are**.

Allowed when:

- There is no usable stale cache.
- Placeholder geometry matches the final cards / hero / rows the user will see.
- Known poster, palette, or average colour may tint the placeholder.
- Focus navigation still has a sensible landing target (Search's empty poster grid is the known
  exception for remote focus from frame one).

Forbidden:

- Shimmer theatre that does not match layout.
- Grey tiles that never resolve into a distinct error.
- Skeletons that fight continuity when stale data was available.

## Verification notes

Image pipeline, cache ownership, blur, and card→detail handoff are **high risk**. Mark
`validation pending` until exercised on the platforms you changed.
