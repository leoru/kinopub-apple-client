# 03 — Library and History navigation

**Status:** Not started (partial pieces exist)  
**Goal:** Replace fragmented Library surfaces with **one vertically scrolling Library** experience,
and give **History** its own coherent vertically scrolling screen. Do **not** merge Library and
History into a single destination.

## Problem

Library-related content is currently split across tabs/screens (watchlist, folders, recently watched,
bookmarks catalog pieces). History exists but is not a first-class, clear vertical surface. Users
should get Apple-TV-like shelves/rows in one Library scroll, and a dedicated History scroll.

## Accepted behavior

- **Library:** one vertical scroll of rows (watchlist first when non-empty, then bookmark folders by
  recent update, plus any library summary rows we keep). Title opens the full folder/grid screen;
  artwork is visible without opening.
- **History:** its own destination — vertical list/rows of recently watched titles, not a buried
  context-menu-only afterthought (context menu entry may remain as a shortcut).
- Remove redundant split screens that duplicate the same collections without adding capability.
- Pagination / cache rules follow [data-continuity](../policies/data-continuity.md).

## Checklist

- [ ] Inventory current Library / Bookmarks / Watchlist / Recently Watched screens and pick survivors
- [ ] Ship single vertical Library composed of `MediaRowsView` (or successor)
- [ ] Ship dedicated History screen in the shell (sidebar / tab placement TBD with stage 02)
- [ ] Folder full screens remain drill-ins, not parallel top-level chaos
- [ ] Bookmark create-folder flow (today bookmarking needs an existing folder)
- [ ] Paginate folder contents (`BookmarkItemsRequest` limit)

## Validation

- [ ] From cold Library focus, Up reaches shell chrome; Down walks rows
- [ ] History independent of Library; both return with cached content
