# Navigation and search

## Evergreen

- Shared `TabView` + `.sidebarAdaptable` is the modern multiplatform shell (sidebar on Mac/TV,
  bottom tabs on iPhone).
- `Tab(role: .search)` owns the system search role where available.
- `TabViewCustomization` / tab `badge` / hide-reorder APIs are **unavailable on tvOS** — do not plan
  tvOS tab customization around them. UIKit `UITab.badgeValue` exists if you host UIKit tabs.
- `.tabBarMinimizeBehavior` scroll values are effectively iPhone-oriented.
- Search suggestions on tvOS are text-oriented; do not expect poster-rich suggestion rows.
- Prefer one `NavigationStack` per tab with a unified route enum + destination registry.

## Project decisions

- Destinations: single `Route` + `RouteDestination`.
- Zoom: `matchedTransitionSource` / `navigationTransition(.zoom)` on **iOS/tvOS** from poster /
  banner / cast. **macOS:** API may be unavailable — say so; do not claim transitions "everywhere".
- macOS profile: `tabViewSidebarBottomBar`. tvOS profile stays top/header for now (API ceiling).
- Re-selecting a tab pops that tab's stack to root.
- Settings must become a real sidebar destination with grouped sections (feature stage: Access and
  app shell) — not an eternal placeholder.

## Superseded

- Netflix-style Home focus-preview driving a full-bleed hero from shelf focus
  (`showsFeaturedPreview`) — deleted; do not revive.
- Hand-rolled multi-stack tab shells when `.sidebarAdaptable` covers the need.
