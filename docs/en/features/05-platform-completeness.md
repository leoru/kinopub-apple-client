# 05 — Platform completeness and appearance

**Status:** Not started  
**Goal:** Deliberate light theme, Top Shelf, and required platform integrations **before** advanced
subtitle work.

## Accepted behavior

- Light appearance is a planned pass — not a partial toggle. Until then, force dark.
- Top Shelf extension shows useful continue-watching / featured items when the platform allows.
- Each platform keeps native shell behaviors (sidebar customization on Mac, search role, etc.).
- Downloads remain non-TV; gate until solid.

## Checklist

- [ ] Light theme design pass (semantic colours, materials, blur legibility, artwork contrast)
- [ ] Remove forced `.preferredColorScheme(.dark)` / `UIUserInterfaceStyle = Dark` only when light works
- [ ] Top Shelf extension target + content provider
- [ ] macOS Settings scene / menu wiring polished with stage 02
- [ ] iOS compact layout pass for Library/History single-scroll model
- [ ] Feature-flag Downloads if incomplete

## Depends on

Stages 01–04 should be usable first so theme and Top Shelf wrap a coherent app, not a construction site.
