# Cross-platform

## Evergreen

- Raising the deployment target to 26 removes little `#if os` by itself. Most branches are permanent
  (API missing on a platform, or 10-foot vs pointer design). Prefer `@available` cleanup and
  file-splitting over nested `#if` forests.
- macOS: scenes, `CommandGroup`, window style, tabbing (`automatic window tabbing` off if the player
  must not merge into the library window), sidebar customization.
- iPhone: compact tabs, sheets, touch gestures.
- tvOS: focus, limited tab customization, no Downloads UI.

## Project decisions

- Single target `KinoPubAppleClient` / product `KinoPub`.
- Shared shell via `.sidebarAdaptable`; platform-specific tab contents and profile placement.
- Light appearance is a dedicated **platform completeness** stage — do not half-enable light early.
- Verify high-risk UI on **each platform you touched**, not tvOS alone.

## Pitfalls

- Assuming DocC lists every tvOS availability correctly — check SDK interfaces.
- Porting community-fork UI chrome; steal services/models only.
