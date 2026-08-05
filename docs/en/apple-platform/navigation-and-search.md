# Navigation and search

## Evergreen

- Prefer one `NavigationStack` per tab with a unified route enum + destination registry.
- **iPhone / iPad:** `Tab(role: .search)` pins Search on the **trailing** edge — do **not** use
  legacy `.tabItem` for Search (that keeps it as a normal left-side tab).
- **tvOS:** Search is a normal first tab (left of Home). Do **not** use `Tab(role: .search)` on
  tvOS when Search must lead the bar — the search role pins trailing.
- **macOS:** no Search tab and no Settings tab in the library window. Settings is the Settings
  window (`⌘,` / App menu). Search is a **compact trailing toolbar field** (Finder/Photos) —
  apply `.searchable(..., placement: .toolbar)` on each tab's `NavigationStack`, **never** on
  `TabView` and never `.toolbarPrincipal` (giant center field). Probe-confirmed with
  `.tabBarOnly` on macOS 26/27. Suggestions use the system menu dropdown; **Return** opens the
  Search results surface. Leading **Back** returns to the previous tab when Search was
  entered from browse/toolbar/filter (`canReturnFromSearch`); once a title is pushed,
  system NavigationStack back/forward own that slot. Do not put unrelated controls in
  `.navigation` on macOS. Filters on Search results stay in `.accessoryBar`.
- `TabViewCustomization` / tab hide-reorder are **not** wired on macOS production — omitting
  `.tabViewCustomization` leaves tabs fixed (no Edit / hide). Also `.toolbar(removing: .sidebarToggle)`
  and `CommandGroup(replacing: .sidebar)` so the sidebar cannot be collapsed from chrome or the
  View menu. Those customization APIs remain **unavailable on tvOS**.
- `.tabBarMinimizeBehavior` scroll values are effectively iPhone-oriented.
- Search suggestions on tvOS are text-oriented; do not expect poster-rich suggestion rows.

## Shipping shell (temporary rollback)

Classic system `TabView` tab bar everywhere until `.sidebarAdaptable` / locked sidebar is done
the **system** way (docs + device checks) — not hand-rolled Button-row sidebars or private chrome:

- **tvOS:** `.tabBarOnly` — Search · Home · Movies · Shows · Library · Settings
- **macOS:** `.tabBarOnly` — Home · Movies · Shows · Library; compact trailing toolbar search
  (`macToolbarSearch()`); Return → Search results view
- **iPad:** `.tabBarOnly` — Home · Movies · Shows · Library · Settings + trailing Search role
- **iPhone:** bottom bar — same as iPad

This is a deliberate pause on sidebar chrome, not a design decision to drop the evergreen rules.

## Project decisions

- Destinations: single `Route` + `RouteDestination`.
- Zoom: `matchedTransitionSource` / `navigationTransition(.zoom)` on **iOS/tvOS** from poster /
  banner / cast. **macOS:** API may be unavailable — say so; do not claim transitions "everywhere".
- Re-selecting a tab pops that tab's stack to root.
- When macOS returns to `.sidebarAdaptable`: profile in `tabViewSidebarBottomBar`; omit
  `.tabViewCustomization`; keep sidebar locked via `.toolbar(removing: .sidebarToggle)` +
  `CommandGroup(replacing: .sidebar)`.

## PARKED — sidebarAdaptable (bring back with system APIs)

`.sidebarAdaptable`, locked sidebar chrome, Home segmented Movies/Series, and related split
experiments are **parked**, not discarded. Prototypes: [`Views/UILab/`](../../../KinoPubAppleClient/Views/UILab/).

Open problems (why we rolled back): sidebar toggle / hide / edit without fighting HIG;
`List(selection:)` + associated-value tabs. Do **not** invent Button-row sidebars — conflicts
with [apple-native-design](../policies/apple-native-design.md). Finish with public Tab / toolbar
APIs from the evergreen list; do not paper over gaps with private UIKit/AppKit hacks.

## Superseded

- Netflix-style Home focus-preview (`showsFeaturedPreview`) — deleted; do not revive.
- Hand-rolled multi-stack tab shells when a stock `TabView` covers the need.
