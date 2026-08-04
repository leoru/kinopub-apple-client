# Agent workflow

How agents approach work in this repo. Authority and preservation rules live in
[`AGENTS.md`](../../../AGENTS.md).

## Sequence

1. **Capability and data flow** — what the user can do, which services / models / stores change,
   what old path to remove or merge.
2. **Recon** — read the relevant policy, feature doc, and 1–2 Apple-platform knowledge sections.
   Check Apple API / HIG, then our code, then reference apps / community fork / mature libraries.
3. **Presentation**
   - If the control is predetermined by the system → implement it.
   - If a noticeable UI piece is ambiguous → isolated 2–3 variants (see below), wait for a choice.
4. **Small slice** — one reviewable change. Do not touch unrelated dirty files.
5. **Verify by risk** — see tiers below. Be honest when verification is deferred.
6. **Docs** — update the feature doc checklist / validation notes after acceptance. Touch README
   only for macro-stage or public-capability changes. Append notable facts to `CHANGELOG.md`.

## Borrow before build

Order of reuse:

1. Apple public API (and isolated private helpers when already accepted).
2. Existing atoms in `KinoPubUI` / app services.
3. Proven code from reference apps or the `community` remote (backend slices only for UI-adjacent
   ports — keep our screens).
4. Mature libraries (Nuke, Boutique, Introspect, palette extractors, Pow / Wave, etc.) after a short
   capability review: which hole they close, why system API is insufficient, platforms, wrapper
   boundary, maintenance cost.
5. New in-house code.

Do not add a dependency because a list of cool repos exists. Do not rewrite a working library-shaped
problem overnight.

## Prototype variants

Use when the user asks, or when a visible custom piece has multiple defensible directions.

- Default **3** variants; max 5. Each needs a named axis (layout, density, motion, interaction).
- **Where they live:** `Packages/KinoPubUI/Sources/KinoPubUI/Previews/`, one
  `<Thing>Variants.swift` per ambiguous piece, wrapped in `#if DEBUG`. Use the `VariantGallery` /
  `Variant` containers in `VariantGallery.swift` so the axis is labelled and the candidates sit side
  by side. Never build variants in production paths.
- Every variant must be fully interactive with realistic content. A static mock is not a variant.
- Previews do not prove tvOS focus. Anything focusable still needs a run on the remote.
- Promote only the chosen variant, then **delete the variants file** — a stale gallery is worse than
  no gallery. Keep it only if the user asks.
- Predetermined system controls (Play button style already decided, native player, Form settings)
  do **not** get variant theatre.

## Feature flags and incomplete work

- Prefer finishing a thin vertical slice or **feature-gating** it (`FeatureFlags`,
  Downloads-style) over shipping half-chrome. An off flag must skip the work
  (network, sampling), not only hide UI.
- Do not claim recommendations / Top Shelf / light theme / advanced subtitles exist when they do not.
- Dual subtitles and other parked surfaces stay parked until their feature doc says otherwise.

## Verification tiers

| Risk | Examples | Required before `done` |
| --- | --- | --- |
| Low | Copy, localization keys, swap label → existing SF Symbol / asset | Diff review; build optional |
| Medium | New reusable view, layout tweak, model mapping, image state | `#Preview` / component harness or focused package/target build |
| High | Navigation, focus, sidebar, blur/materials, player, cache/session lifetime, private API | Build affected platforms + visual or remote/input check, or remain `validation pending` |

Long builds and single-machine limits are real. Deferred verification is allowed; silent
"everything landed" claims are not.

## Anti-patterns seen here

- Inventing design-decision blockers that the user did not set.
- Encoding agent assumptions into README / plans, then treating them as law.
- Marking phases complete after tvOS-only compile while macOS sidebar / banner / artwork broken.
- Overwriting user blur / glass / banner / badge decisions.
- Placeholder grids that violate continuity policy.
- Treating one stream survey as a global ban on capability badges the user still wants when flags exist.
