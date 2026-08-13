# Plan: Library sidebar (parity with the shipping KinoPub client)

> **Archived 2026-08-13.** Survived: the sidebar shape and the section list, now accepted behavior
> in ROADMAP stage 3. The macOS shell landed; iPadOS, tvOS and the iPhone list are open there.


> **Dated implementation plan — not living authority.** Accepted behavior:
> [03-library-and-history](../../../ROADMAP.md). Shell rules:
> [navigation-and-search](../../../.claude/skills/apple-chrome/SKILL.md). Cache rules:
> [data-continuity](../../../AGENTS.md).

Date: 2026-08-06. Status: not started.

## Shape

```
┌ Library ─────────────────────────────────────────────┐
│ Watchlist        │                                   │
│ Movies           │   vertical poster grid of the     │
│ History          │   selected section                │
│ Downloads        │                                   │
│ ── ЗАКЛАДКИ ──   │                                   │
│ хочу посмотреть 525                                  │
│ lusya            46                                  │
│ Создать закладку +                                   │
└──────────────────────────────────────────────────────┘
```

Default selection: **Watchlist**. Last selection is remembered per launch in `UserDefaults`; a
missing/deleted folder falls back to Watchlist.

## What already exists

Nothing here needs new networking except folder rename (see §Undocumented endpoints).

| Need | Have |
| --- | --- |
| Watchlist | `VideoContentService.fetchWatchingSerials(subscribedOnly:)` |
| Unfinished movies | `fetchWatchingMovies()` — **implemented, called from nowhere** |
| History | `fetchHistory(page:)` + `HistoryView.cards(from:)` |
| Folders + counts | `fetchBookmarks()` (`Bookmark.count`), `fetchBookmarkItems(id:page:)` |
| Create / delete folder | `UserActionsService.createBookmarkFolder(title:)` / `removeBookmarkFolder(id:)` |
| Remove from history | `clearHistoryForItem(id:)` |
| Remove from folder | `toggleBookmark(itemId:folderId:)` |
| Unsubscribe | `toggleWatchlist(id:)` |
| Downloads | `DownloadsCatalog` / `DownloadsView` (unbound on macOS today) |
| Grid of `MediaCard` with pagination hook | `MediaCardsListView` (KinoPubUI) |
| TTL cache per section | `ContentStore` + `RowKey` (`.watchlist`, `.history`, `.folder(Int)`) |
| Create-folder alert UI | `MediaCardMenuCoordinator` + `mediaCardNewFolderAlert` |

## Files

**New — `KinoPubAppleClient/Views/Library/`**

- `LibrarySection.swift` — `enum LibrarySection: Hashable { watchlist, movies, history, downloads,
  folder(Bookmark) }` with `title`, `systemImage`, `rowKey`, `isPaginated`.
- `LibraryModel.swift` — `@MainActor ObservableObject`: folder list with counts, `@Published var
  selection: LibrarySection`, create/delete folder, selection persistence.
- `LibrarySectionCatalog.swift` — one section's `[MediaCard]` + pagination, read/written through
  `ContentStore` so a cold launch paints before the network answers.
- `LibrarySidebar.swift`, `LibrarySectionGrid.swift`.

**Changed**

- `Views/Bookmarks/List/LibraryView.swift` → shell only (split view vs iPhone list).
- `States/Navigation/Routes.swift` → `case librarySection(LibrarySection)` for the iPhone push.
- `Services/Cache/RowKey.swift` → `.watchingMovies` in the `.watch` family.

**Deleted at the end (only once superseded, in one commit, so the diff shows the trade)**

`PersonalLibraryCatalog`, `WatchlistView`, `RecentlyWatchedView`, `BookmarksView`, and the
`watchlist` / `recentlyWatched` / `bookmarks` cases of `NavigationTabs`.

## Phases

1. **Model + catalog.** `LibrarySection`, `LibraryModel`, `LibrarySectionCatalog`, `.watchingMovies`
   key. No UI change; the old Library keeps working.
2. **Shell A — macOS / iPadOS.** `NavigationSplitView` inside the Library tab, sidebar + grid,
   default Watchlist. On macOS add `.toolbar(removing: .sidebarToggle)` — otherwise the system puts
   a collapse control into a toolbar that already owns the tab bar and the compact search field.
3. **Actions.** Create folder from the sidebar (reuse the existing alert), delete folder via context
   menu, card actions (remove from history / from folder, unsubscribe).
4. **Shell B — iPhone.** Podcasts-shaped `List` of sections + Bookmarks group, pushing
   `.librarySection`; "Recently updated" grid under the list.
5. **tvOS.** Same sections, focus-correct. **Probe first** (see below).
6. **Cleanup + docs.** Delete superseded surfaces, tick the feature checklist.

## Open risk — tvOS focus

`NavigationSplitView` exists on tvOS, but whether it gives the native collapse-to-icons sidebar and
sane focus (left out of the grid, back into it, no traps) is **not** settled from documentation.
The macOS toolbar-search work in this same area proved the docs and the rendered result can
disagree, so phase 5 starts with a throwaway probe app (three variants, screenshots) exactly like
[navigation-and-search](../../../.claude/skills/apple-chrome/SKILL.md) records for `.searchable`.

Fallback if `NavigationSplitView` will not carry focus on tvOS: `TabView(.sidebarAdaptable)` scoped
**inside** the Library tab. The parked ban in navigation-and-search is on the **app-level** sidebar
shell, not on a nested one — call this out in the commit so the parked decision is not read as
reversed.

## Undocumented endpoints

The public API docs are not the boundary of what the service can do — the site itself calls
endpoints that are not in them. Known lead, **unverified**:

- `https://kino.watch/favorites/update?id=<item id>` — shape, verb, auth and effect all unconfirmed.

Rule for this plan: before writing "the API cannot do X" (folder rename is the live case), probe the
site's own calls and record what was actually observed — request, response, auth — in this file.
Anything shipped on an undocumented endpoint gets a comment at the call site saying it is
undocumented and how it was verified, so a future break is diagnosable.

## Validation

Beyond the feature-doc checks: folder counts in the sidebar must match the reference client for the
same account, and switching sections must not refetch a section whose TTL is still warm.
