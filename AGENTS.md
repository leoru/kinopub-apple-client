# Working agreement

Read this before changing code. Product overview and macro stages live in
[README.md](README.md). Detailed behavior and checklists live in feature docs. Durable rules live
in policies. Platform how-tos live in the Apple-platform knowledge base.

## Authority (highest wins)

1. **The user's current explicit decision** in this conversation.
2. **Accepted feature decisions** in [`docs/en/features/`](docs/en/features/).
3. **Policies** in [`docs/en/policies/`](docs/en/policies/).
4. **Implementation plans** in [`docs/en/plans/`](docs/en/plans/) — how, not whether.
5. **Research / archive evidence** — never automatic requirements.

If sources conflict, stop only the disputed part and ask. Do **not** invent blockers, close open
design questions with "Apple defaults", or rewrite docs to rationalize an implementation.

## Preserve user work

- Treat every pre-existing modified or untracked file as user-owned.
- Re-read a file immediately before patching it.
- Prefer narrow patches. Do not revert, wholesale-replace, or reformat unrelated work.
- Do not change requirements, policies, feature docs, or README merely to match what you built.

## Non-negotiables

- **One multiplatform target.** Platform differences use `#if os(...)`. Do not add a second app target.
- **Native Apple UI first.** Stock SwiftUI / AVKit / system UIKit-AppKit bridges before custom chrome.
  Custom UI needs a named missing API, rejected alternatives, and a maintenance cost. See
  [apple-native-design](docs/en/policies/apple-native-design.md).
- **One component catalogue, templated pages.** A page is a list of typed sections built from shared
  components — never a screen-specific copy of something that already exists. Trying 2–4 variants of
  *one* component behind a switch is fine; two screens growing their own version of the same idea is a
  defect. TVML's `productTemplate` is the reference spec for what a media page is. See
  [component-catalogue](docs/en/policies/component-catalogue.md).
- **Multiplatform-native, tvOS-quality.** Ship a real app on tvOS, iOS, iPadOS, and macOS. tvOS sets
  the media / focus / 10-foot bar; other platforms get their own native controls, not TV chrome
  forced sideways.
- **Focus must work on tvOS.** Interactive controls are reachable and visibly focusable. Avoid
  `.buttonStyle(.plain)` unless you have verified focus. Rows screens use `MediaRowsView` and do
  not put inert reserved space above content.
- **Continuity before placeholders.** Stale local data and already-loaded artwork beat blank screens.
  Exact-layout skeletons are allowed only for true cold loads. See
  [data-continuity](docs/en/policies/data-continuity.md).
- **System colours.** `Color.KinoPub.background` / `.text` / `.subtitle` resolve to platform colours.
  **Dark only, forced on every platform,** until the deliberate light-theme stage. tvOS ships no
  semantic background colour (`systemBackground` is iOS-only), so the TV base is real black. The
  token must stay **opaque**: a transparent one no-ops every `.background(…)` and every `.opacity()`
  scrim derived from it. Liquid Glass samples the *content* over the fill — never rely on the page
  fill to feed glass.
- **Telemetry.** No third-party SDK today: TestFlight / Xcode Organizer already deliver crashes, and
  distribution is personal builds / TestFlight. Product analytics is a late-stage item. Do not add
  Firebase, Sentry, or similar without an explicit decision from the user.
- **Downloads are non-TV only.** Feature-gate incomplete surfaces rather than inventing half-UI.
- **New API calls go through `KinoPubBackend`** (Endpoint + model + service protocol + mock).
- **Localization** through `Localizable.xcstrings` (RU + EN). Maintained *docs* are English-only.

## Workflow

Logic and data flow first; presentation second. Borrow before build. Ambiguous UI gets 2–3 isolated
variants; predetermined system controls do not. Verify by risk, not ritual. Details:
[agent-workflow](docs/en/policies/agent-workflow.md).

## Documentation map

| Document | Owns |
| --- | --- |
| [README.md](README.md) | Public overview, differentiators, current macro stage, setup |
| [CHANGELOG.md](CHANGELOG.md) | Notable shipped changes and agent-relevant implementation facts |
| [docs/en/policies/](docs/en/policies/) | Durable design / continuity / workflow rules |
| [docs/en/features/](docs/en/features/) | Feature behavior, small checklists, flags, validation |
| [docs/en/apple-platform/](docs/en/apple-platform/) | Categorized Apple API / HIG / pitfalls knowledge base |
| [docs/en/plans/](docs/en/plans/) | Dated implementation history — not living authority |

README changes only when public positioning, a macro stage, or a broad capability changes — not after
every PR. Tick detail checkboxes in the relevant feature doc instead.

## Style

- 2-space indentation.
- SwiftUI: `@StateObject` view models via `@autoclosure @escaping` initializers, matching `Views/`.
- Services: protocol + `…Impl` + `…Mock`. View models: `ObservableObject`, `@MainActor` when touching UI.
- Keep `#Preview` / `PreviewProvider` working for reusable UI.

## Driving the remote

There is no Simulator.app on current Xcode. The simulator window is hosted by **Device Hub**
(`com.apple.dt.Devices`). Focus the window title bar; arrow keys + Return are the D-pad. Escape is
**not** Menu — use the on-screen remote `‹` button. Focus bugs do not show in previews.

## Community fork

Track [dungeon-master-xx/kinopub-apple-client](https://github.com/dungeon-master-xx/kinopub-apple-client)
as remote `community`. Steal Request/Model/Service slices only. Never rebase our UI onto theirs.
Details: [docs/en/community-fork.md](docs/en/community-fork.md).
