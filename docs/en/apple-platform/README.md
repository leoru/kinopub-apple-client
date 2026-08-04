# Apple-platform knowledge base

English, categorized guidance distilled from the July 2026 research pass and later decisions.
**Policies win** when this conflicts with product choices. Dated Russian source snapshots live in
[`docs/archive/research-2026-07/`](../../archive/research-2026-07/).

## How to use

Read **this index + one or two** topic files for the task. Do not re-derive the whole research tree
every session.

| If you are changing… | Open |
| --- | --- |
| Grids, shelves, card sizing, Dynamic Type | [layout-and-containers.md](layout-and-containers.md) |
| Glass, materials, blur, scroll edges, toolbars | [materials-blur-and-chrome.md](materials-blur-and-chrome.md) |
| Tabs, search, sidebar, navigation transitions | [navigation-and-search.md](navigation-and-search.md) |
| Focus, lockups, parallax, Top Shelf | [focus-and-tvui.md](focus-and-tvui.md) |
| Player, AVKit, subs, skip markers | [player-and-media.md](player-and-media.md) |
| `#if os`, scenes, menus, windows | [cross-platform.md](cross-platform.md) |
| Images, cache, palette, a11y atoms | [images-and-persistence.md](images-and-persistence.md) |
| TMDB / Kinopoisk / Trakt / matching | [metadata-integrations.md](metadata-integrations.md) |

## Status legend

- **Project decision** — accepted for this app; implement accordingly.
- **Evergreen** — Apple API / HIG fact still useful on baseline 26+.
- **Needs validation** — plausible but not confirmed on device / latest SDK.
- **Superseded** — research recommendation rejected or replaced (do not revive).

## Baseline

Deployment floor: **tvOS / iOS / macOS 26.0**. Mark 27-only APIs explicitly. Web DocC sometimes omits
tvOS availability — prefer SDK `.swiftinterface` when unsure.
