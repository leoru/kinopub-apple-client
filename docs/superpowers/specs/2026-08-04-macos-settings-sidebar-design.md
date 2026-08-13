# macOS / iOS Settings shell (sidebar catalog)

**Date:** 2026-08-04  
**Status:** Approved for planning  
**Feature doc:** [02-access-and-app-shell](../../../ROADMAP.md)  
**Reference (visual / shell inspiration):** `/Users/sasha/Documents/GitHub/System-Settings` (System Settings recreation — patterns only; not App Store / private-API copy)

## Goal

Replace the flat Profile Form and the tiny macOS Always-on-Top Settings scene with a **shared settings catalog**: category sidebar on macOS, category list on iOS, same Form panes. Prefill the taxonomy so panes can be filled over time. tvOS stays on the existing `TVProfileSettingsView` for this pass.

## Decisions

| Topic | Choice |
| --- | --- |
| macOS entry | `Settings { }` scene (`⌘,` / App menu Settings). Profile sidebar button calls `openSettings()` — same window, no Profile sheet. |
| Layout | `NavigationSplitView` sidebar + detail (System Settings–like), not SwiftUI sample `TabView` toolbar panes. Revisit TabView if sidebar feels wrong in app Settings. |
| Platforms this pass | Shared panes for **macOS + iOS**. **tvOS later**. |
| Empty / future panes | Interactive demo controls (`@State` only, no persistence). Look like system Settings UI; wire later. |
| Downloads | Feature-gated **off** — omit from sidebar until the flag is on. |
| About | **Separate from Settings** on macOS (App menu About → About window), per HIG / SwiftUI docs. iOS: row at bottom of category list. tvOS: separate item later. If About-in-General (System Settings repo) feels better later, we can switch. |
| Live prefs | Keep existing `@AppStorage` / Keychain / `ProfileModel` bindings; move UI into panes, do not reinvent storage. |

## Shell

### macOS

- `Settings { SettingsRootView() }` with fixed-ish width (~720pt), min height ~415pt, content-size style where practical.
- Sidebar ~215pt: `List(selection:)` of `SettingsCategory`, SF Symbol icons, optional section grouping.
- Detail: `NavigationStack` hosting the selected pane (`Form` + `.formStyle(.grouped)`).
- Remove Always-on-Top-only `Views/macOS/Settings/SettingsView.swift` content into **General** (or Appearance if it fits better — prefer General for window chrome).
- Do **not** copy System-Settings private swizzles, graphic-icon bundle IDs, or Tap-to-Radar.

### iOS

- Settings / Profile tab hosts `SettingsRootView`: `NavigationStack` → list of categories → push same pane views.
- About as a trailing/footer row (not a sidebar category).

### tvOS

- Out of scope. Keep `TVProfileSettingsView` + existing bindings until a follow-up.

## Category catalog

Short UI titles. Enum: `SettingsCategory` (`Hashable`, `CaseIterable`) with title, SF Symbol, `isAvailable` (platform + feature flags).

| Category | v1 content |
| --- | --- |
| General | Live: language, account summary, logout, Always on Top (macOS). |
| Playback | Live: stream quality, subtitle preferences. |
| Integrations | Live: Kinopoisk key; demo rows for future sources. |
| Downloads | Hidden while feature flag off. |
| Devices | Demo UI only. |
| Appearance | Demo (dark-only note + placeholder controls). |
| Sidebar | Demo; surface existing tab customization if already wired. |
| Notifications | Demo. |
| Details | Demo (content / sources / metadata visibility). |
| Backups | Demo (sync / iCloud aspirational). |
| Network | Demo (VPN / speed / status placeholders). |
| Advanced | Live DEBUG stream survey where present; otherwise demo debug/log toggles. |

About is **not** a `SettingsCategory`.

## Code layout

```
Views/Settings/
  SettingsCategory.swift
  SettingsRootView.swift
  SettingsSidebarView.swift          // macOS
  Panes/
    GeneralSettingsPane.swift
    PlaybackSettingsPane.swift
    IntegrationsSettingsPane.swift
    DevicesSettingsPane.swift
    AppearanceSettingsPane.swift
    SidebarSettingsPane.swift
    NotificationsSettingsPane.swift
    DetailsSettingsPane.swift
    BackupsSettingsPane.swift
    NetworkSettingsPane.swift
    AdvancedSettingsPane.swift
  About/
    AboutView.swift
```

Reuse (move, don’t duplicate logic):

- `ProfileModel` — account / language / logout
- `KinopoiskSettingsSection` / `KinopoiskKeySettingsModel`
- `StreamQuality`, `SubtitlePreferences` bindings
- `WindowSettings` / Always on Top

`ProfileView` becomes a thin host of `SettingsRootView` on iOS/macOS in-tab paths; macOS primary path is the Settings scene. Retire the Profile settings sheet on macOS.

## Data rules

- **Live controls:** `@AppStorage`, Keychain, `ProfileModel` — persist as today.
- **Demo controls:** `@State` in the pane; reset when the view disappears; never write UserDefaults/Keychain.
- **Search:** none in v1 (no sidebar search).

## Out of scope

- tvOS Settings redesign
- Wiring Downloads / Devices / Network / Backups / Notifications to real services
- Changing feature docs taxonomy beyond aligning names when implementation lands
- Private API icons / System Settings swizzles from the reference repo

## Validation

- macOS: `⌘,` opens sidebar Settings; profile button opens the same; live prefs persist; demo prefs do not.
- iOS: category list → panes; live prefs match previous Profile Form behavior.
- Downloads absent while gated off.
- About opens from App menu on macOS; from list footer on iOS.
- tvOS Profile/Settings unchanged.
- No regression: Kinopoisk keychain service remains separate from auth logout.

## Fallback

If sidebar-in-`Settings` scene feels wrong vs HIG TabView panes, or About-as-separate-window feels wrong vs System Settings General→About, revisit using the System-Settings reference patterns without adopting private APIs.
