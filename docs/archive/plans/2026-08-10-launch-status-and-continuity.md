# Launch status, activity toasts, and stop re-asking for what we already know

> **Archived 2026-08-13.** Survived: the launch rule — paint tabs and cached rails first, never
> block the shell on the whole session — now a ROADMAP stage 1 item. The activity-toast and
> diagnostics design here was never built and is not a requirement.


> Dated plan (2026-08-10), not policy. Captured from a user decision so it is not lost
> while the tvOS rail work continues. Authority: the product rule in
> [data-continuity](../../../AGENTS.md) — *continuity before placeholders*.
> This plan is the tvOS launch case of that rule, plus the diagnostics needed to see it.

## The complaint, stated plainly

Launch is slow on a physical Apple TV — "a minute of waiting" — and while it waits the
app shows an **empty loader**. An empty loader is the worst possible thing to show,
because it says only "something is happening" when the interesting question is *what*,
and because the wait is not one thing but several running at once.

Underneath that, two separate faults:

1. **Nothing is stored.** Every launch re-asks for `history`, `watching/*`, `bookmarks`,
   `user`, `device/*` — a launch trace shows all of them, and `history?perpage=20` alone
   came back **96 KB**. Yet history is the one thing this device knows better than the
   server: *I am the one watching here.* These lists change rarely, and when they do
   change it is almost always **this app** that changed them.
2. **The launch blocks.** Tabs should already be on screen with skeletons, and rails
   should fill in as their data lands. Nothing about a shelf requires the whole session
   to be resolved first.

## What we are building

### 1. Launch status, not an empty spinner

Replace the bare loading view with a **fast-updating status label** naming what is
outstanding. It must handle **two or three at once** — "Checking session · Loading
history" — because that is what is actually happening; a single-line "Loading…" is the
empty spinner with extra steps.

Requirements:

- Driven by a small activity registry: work registers a named, user-facing activity and
  unregisters when it settles. The label renders whatever is currently registered.
- Names are product words ("History", "Watchlist", "Session"), not endpoint paths.
- It must never be the reason the screen exists. If tabs can be shown, show tabs.

### 2. Activity toasts as an overlay

Where there is **no** loading view, the same registry feeds overlay toasts: what we are
waiting for, which requests went out, which errors came back. Debug-toggleable, off by
default in release. This is the "what is it doing" channel for a screen that is
otherwise already usable.

Reuse `HudToast`; do not grow a second toast component (component-catalogue rule).

### 3. Status where a spinner already exists

On surfaces that legitimately show a spinner — the detail page — put the same status
text at the spinner instead of beside it. **Conditional on it not spoiling the
component**: if threading status into that view distorts it, skip it. The toasts are
sufficient; a worse-looking detail page is not an acceptable price for a status line.

### 4. Persist the lists, stop re-asking

Local data is the source of truth on this device until something says otherwise:

- Cache `history`, `watching/*`, `bookmarks` locally; render from cache immediately at
  launch and refresh behind it. Never blank a populated list to re-fetch it.
- Local progress already beats the server's copy for anything watched on this device —
  it must win at launch, not be overwritten by a slower remote answer.
- These lists mostly change **through this app**, so a write is the natural moment to
  update the cache; a launch is not.

### 5. iCloud sync — decision needed

Raised as "надо бы айклауд синк что ли общий ну и получше что-то мб". Not specified yet.
Open questions before any code: what syncs (progress only, or bookmarks and settings
too), conflict rule between two devices watching the same title, and whether kino.pub's
own account state stays authoritative. **Do not start this** until it is answered — it
is the kind of thing that is easy to build twice.

## Order

1. Activity registry + launch status label (the visible fix).
2. Activity toasts overlay, debug-gated.
3. Cache-first history / watching / bookmarks; skeleton launch that never blocks tabs.
4. Detail-page spinner status, only if it costs the component nothing.
5. iCloud sync — after the design questions above are answered.

## Measurement, before and after

The "a minute" figure is from a **physical** Apple TV; the recent simulator run felt
faster but was **not measured**, and the two are not comparable. Before claiming any
launch improvement:

- measure on the physical device, the same way, twice;
- keep `ArtworkLog` and the API trace on so the timeline is attributable.

Do not report a launch win from a simulator impression.

## Related note: prefetching is not free

An eager artwork warm-up was added and then pulled back on 2026-08-10 the same day: a
launch trace showed wide art at 456 KB, 1073 KB, 352 KB being fetched in bulk while the
session was still resolving. Prefetching now comes only from
`UICollectionViewDataSourcePrefetching`, which UIKit scopes to cells about to appear.
Any future "warm everything" impulse should be weighed against this launch budget first.
