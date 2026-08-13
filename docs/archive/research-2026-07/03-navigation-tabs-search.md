# 03 — Navigation, tabs, and search

Condensed English summary of a 2026-07-25 research pass, baseline 26.0, 27-only noted separately.
Availability was cross-checked against the installed SDK's `.swiftinterface`
(`AppleTVOS27.0.sdk/…/SwiftUI.swiftmodule/arm64-apple-tvos.swiftinterface`), because Apple's web docs
in several places omit tvOS from a platform list rather than showing
`@available(tvOS, unavailable)` explicitly — the interface is the ground truth used below. Current
guidance lives in
[`.claude/skills/tvos-surface/SKILL.md`](../../../.claude/skills/apple-chrome/SKILL.md).
Most structural recommendations here **shipped**: `TabsNavigationView` now uses one `TabSection`
tree (Browse / Library / Folders) with `customizationID` per tab, matching this report's sketch.
Russian original: `03-navigation-tabs-search.ru.md` (gitignored, local only).

## TL;DR (at the time)

- **`TabViewCustomization` does not exist on tvOS** — confirmed `@available(tvOS, unavailable)` in
  the SDK, along with `tabViewCustomization(_:)`, `customizationBehavior`, `defaultVisibility`,
  `TabContent.hidden`, and `TabContent.badge`. Hide/reorder/badge a tab by system means: **not
  possible on tvOS, in 26 or 27.** Customization is iOS/iPadOS/macOS/visionOS only.
- **No tab badges on tvOS, full stop, in SwiftUI.** The only escape hatch is UIKit: `UITab.badgeValue`
  / `UITab.subtitle` exist on tvOS 18+, but that means hosting a `UITabBarController`, and that
  controller has **no sidebar mode on tvOS** (`UITabBarControllerModeTabSidebar` is
  `API_UNAVAILABLE(tvos)`) — badges would cost the sidebar. Not recommended.
- **`.tabBarMinimizeBehavior(_:)` is a no-op for us on tvOS.** The modifier exists everywhere at
  26.0, but the only useful values (`.onScrollDown`/`.onScrollUp`) are iPhone-only.
- **Floating search-as-a-tab exists everywhere including tvOS** (`Tab(value:role:.search)`, tvOS
  18+), but the "floating" *presentation* (pill button, auto-focused field) does not —
  `.searchToolbarBehavior(.minimize)` and `.tabViewSearchActivation(.searchTabSelection)` are both
  tvOS-unavailable. On tvOS, `.search` role gives correct sidebar placement and the system icon —
  nothing more. tvOS instead gets a **full-screen search screen** (on-screen keyboard grid + results
  below it) — the expected native tvOS pattern, not a gap to fill.
- **Top-bar vs. sidebar on tvOS is a style choice, not a side effect**:
  `.tabViewStyle(.tabBarOnly)` (tvOS 18+) for the classic top bar, `.sidebarAdaptable` for the
  sidebar. 27 adds `.defaultTabBarPlacement(.sidebar/.tabBar)` as a declarative alternative.
- **Search suggestions work on tvOS from 16.0, but with a hard limit**: "In tvOS, searchable
  modifiers only support suggestion views of type `Text`." No `Label`, no posters, no custom rows.
- **`tvOS 26 changed sidebar safe area behavior`**: the trailing content is inset by the sidebar's
  width and *can* draw content outside its safe area, underneath the sidebar. This is what makes
  `backgroundExtensionEffect()` meaningful there — and, per this session's later, harder-won lesson
  in `materials-blur-and-chrome.md`, also what makes it easy to misuse.

## What was available at baseline 26

Tab structure: `Tab`/`TabSection`/`TabRole.search` at tvOS 18.0; `TabRole.prominent`,
`defaultSectionExpansion`, `defaultTabBarPlacement` are 27-only. `TabContent.badge`,
`.hidden`, `.defaultVisibility`, `.customizationBehavior`, drag/drop/swipe on sidebar rows: all
**tvOS-unavailable**. `TabViewCustomization` and its modifier: **tvOS-unavailable**.

Search: `.searchable` (tvOS 15.0), `.searchSuggestions` (tvOS 16.0, `Text`-only there),
`.searchCompletion` (15.0), `.searchScopes` (16.4). tvOS-unavailable: `.searchable(isPresented:)`,
`.searchFocused`, every `SearchFieldPlacement` except `.automatic`, `.searchToolbarBehavior(.minimize)`,
`.tabViewSearchActivation`, token search.

Navigation: `NavigationStack`/`NavigationPath` (16.0), `NavigationSplitView` (16.0, but **always
collapses to a stack on tvOS** — its `columnVisibility` means nothing there), `.navigationTransition(.zoom)`
(18.0), `backgroundExtensionEffect()` (26.0, tvOS included). `CommandGroup` (macOS menu bar):
**tvOS-unavailable as a type**. `Picker(.tabs)` (`TabsPickerStyle`, VoiceOver reads it as "tabs" —
useful for a seasons picker): 27.0.

## What shipped from this report

`TabsNavigationView` collapsed from three parallel platform trees (~630 lines) into one
`TabSection`-based tree (Browse / Library / Folders) with `customizationID` per tab, matching this
report's sketch — see the current file. The legacy `.tabItem`/`.tag` fallback and the
`if #available(iOS 18, tvOS 18, macOS 15)` branch are gone (superseded by the baseline-26 raise).

Still open, tracked in feature docs rather than here: badge semantics (watchlist "new episodes"
vs. subscribed-series count; Downloads "active" vs. "downloaded" count), search suggestions/history,
`MainRoutes.==` implemented via `hashValue` comparison (a correctness bug — hash collisions would
read as equal routes), the five parallel route enums instead of one `Route` type, and
`NavigationState` as a ten-`@Published`-array `ObservableObject` instead of `@Observable`.

## Badges on tvOS: what's actually possible

Since `TabContent.badge` is unavailable, the practical choices are: (a) a second `Text` in a tab's
`Label` — unverified whether SwiftUI surfaces it as a sidebar-row subtitle the way `List` does, but
`UITab.subtitle` existing in UIKit on tvOS suggests underlying platform support; (b) a count folded
into the tab title string (what the app did originally — works, but breaks localization and
right-alignment); (c) a `sectionActions` label in a `TabSection` header (tvOS 18+, available); (d) the
UIKit escape hatch above, rejected for costing the sidebar. Recommendation was (a) with (b) as
fallback, verified on-device.

## Search: the floating-search question, resolved

Search is **one API with different presentation** per platform, plus two iOS/iPadOS/macOS-only
modifiers tvOS doesn't have. On tvOS, `Tab(role: .search)` + `.searchable` gives a sidebar "Search"
row with the system icon; selecting it opens the system's full-screen search keyboard. There is
nothing further to build there — no floating field, no minimize behavior, by design. Suggestions
must degrade to `Text`-only on tvOS: recents (with a way to clear them, per HIG privacy guidance),
popular queries, and title autocompletion, grouped with `Section` (documented as allowed, but
untested in combination with the tvOS `Text`-only constraint).

## What was borrowed

**Rivulet** (`TVSidebarView.swift`): a snapshotted sidebar-tab-set that only re-syncs when the user
isn't mid-focus in the sidebar (the app's `sidebarFolders` snapshot follows this pattern); an empty
`TabSection("")` as a cheap visual divider before Settings; `.toolbarVisibility(_, for: .tabBar)` to
hide the sidebar on a detail push. **Not borrowed**: their swizzle of
`UIView.shouldUpdateFocus(in:)` to stop tvOS sidebar focus from leaking sideways — a private-API
fragility this app's rules reject; it stands as evidence, not as code, that sidebar focus needs
device verification.

**silo-apple** (`ContentView.swift`): one `NavigationStack` outside `TabView` with a single
`.navigationDestination(for: Route.self)` for the whole app — the fix this report and later A-1
pointed at for the app's five-parallel-route-enum problem. Also: silo dropped
`TabView(.sidebarAdaptable)` on tvOS entirely in favor of a custom top bar, specifically because the
system sidebar was observed claiming leftward focus — a warning to verify on-device before
committing to the sidebar shape, not a pattern to copy.

## tvOS pitfalls and unresolved questions from this report

No badges, no user-facing customization (only author-set `tabPlacement(.pinned/.sidebarOnly)`);
changing the tab set while the sidebar has focus risks stealing focus; icons in tvOS tabs were
observed elsewhere to inflate the focus pill (silo moved to text-only tabs on TV); tvOS 27 stopped
auto-tinting buttons with the asset-catalog accent color; tvOS 26's design update does not reach
1st-generation Apple TV 4K or older.

Left explicitly unverified at the time: how `Tab(role: .search)` actually renders in the tvOS 26
sidebar; whether a two-`Text` tab `Label` produces a title+subtitle row there; `Section` inside
`searchSuggestions` under the tvOS `Text`-only rule; `.tabViewStyle(.tabBarOnly)`'s actual tvOS 26
appearance; and — most load-bearing — whether the system sidebar steals focus leftward the way both
reference apps report. Any of these should be device-verified before being treated as settled.
