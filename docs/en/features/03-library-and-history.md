# 03 — Library and History navigation

**Status:** Not started (parts exist; shell decided 2026-08-06)
**Goal:** One **Library** destination with a **native sidebar** of sections, each section its own
vertical poster grid. Reach functional parity with the shipping KinoPub tvOS client's "Мои" tab.
History is a **section of that sidebar**, not a row merged into a Library scroll.

Implementation: [plans/library-sidebar](../plans/library-sidebar.md).

## Problem

Library content is split across parallel top-level surfaces (`watchlist`, `recentlyWatched`,
`bookmarks`, folder screens) that duplicate each other without adding capability, while the one
combined `LibraryView` flattens everything into horizontal shelves — which stops working the moment
a user has ten bookmark folders. The reference client shows the whole personal library as a
sidebar with counts and a grid, reachable in one click.

## Accepted behavior

### Sections (this is the business requirement — do not silently drop entries)

Sidebar order, top to bottom:

| Section | Source | Notes |
| --- | --- | --- |
| **Watchlist** | `/v1/watching/serials?subscribed=1` | **Default selection when Library opens.** New-episode badge stays. |
| **Movies** | `/v1/watching/movies` | Unfinished films. Endpoint is implemented and currently **unused** — this is the gap vs the reference client. |
| **History** | `/v1/history` | Its own section with its own grid; never folded into another list. |
| **Downloads** | local (`DownloadsCatalog`) | Order relative to History is not load-bearing. |
| — separator — | | Header reads as the bookmarks group. |
| **Bookmark folders** | `/v1/bookmarks` | One row per folder, **with the item count** shown like the reference client. Recently-updated first. |
| **Create bookmark** | `POST` create-folder | Last row of the group, mirrors "Создать закладку +". |

- Selecting a section shows a **vertical poster grid** (portrait artwork is correct here — this is
  not a shelf surface).
- Folder rows keep their counts visible without opening the folder.
- Empty sections get an empty state, not a blank pane; a failed load keeps cached content
  ([data-continuity](../policies/data-continuity.md)).

### Actions reachable from Library

- Create a bookmark folder from the sidebar (today creating one is only possible while bookmarking
  an item).
- Delete a bookmark folder from its context menu.
- Rename a folder **if** an endpoint exists — the public API docs have no such call, but
  undocumented site endpoints do exist (lead: `https://kino.watch/favorites/update?id=<id>`,
  unverified). Probe before declaring it impossible; do not ship a fake local-only rename.
- Per-card: remove from history, remove from folder, unsubscribe from watchlist.

### Per-platform shape

- **tvOS / iPadOS / macOS:** sidebar + detail grid, using system split/sidebar APIs. Do **not**
  hand-roll Button-row sidebars ([apple-native-design](../policies/apple-native-design.md)).
- **iPhone:** no sidebar — a Podcasts-shaped `List` of the same sections (with a Bookmarks group)
  that pushes to the section grid, plus a "Recently updated" grid below the list.
- macOS keeps the compact trailing toolbar search and the fixed tab bar
  ([navigation-and-search](../apple-platform/navigation-and-search.md)); the split view must not
  add a sidebar-collapse control to that toolbar.

## Checklist

- [x] `LibrarySection` model + per-section catalog on `ContentStore` (incl. new `watchingMovies` key)
- [x] Sidebar + detail grid shell on **macOS**
- [ ] Same shell on iPadOS
- [ ] Same shell on tvOS with working focus (probe first — see the plan)
- [ ] iPhone Podcasts-shaped list
- [ ] Create / delete bookmark folder from the sidebar
- [ ] Card actions: remove from history, remove from folder, unsubscribe
- [ ] Retire the redundant surfaces once superseded: `WatchlistView`, `RecentlyWatchedView`,
      `BookmarksView`, `PersonalLibraryCatalog`, and the `watchlist` / `recentlyWatched` /
      `bookmarks` cases of `NavigationTabs`
- [ ] Paginate folder contents and history (`BookmarkItemsRequest` / `HistoryRequest` limits)

## Validation

- [x] Library opens on Watchlist (macOS; re-check per platform as their shells land)
- [x] Folder counts in the sidebar match the reference client for the same account
- [ ] tvOS: focus moves left from the grid into the sidebar and back without traps
- [x] macOS: no sidebar-toggle button appears in the window toolbar
- [ ] Cold launch paints cached section content before the network answers

## Superseded

- "One vertical scroll of rows for the whole Library" (the pre-2026-08-06 shape in this file) — it
  does not survive a user with many folders. Rows remain correct for **Home**, not for Library.
