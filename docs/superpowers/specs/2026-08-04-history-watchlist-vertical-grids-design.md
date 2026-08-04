# History / Watchlist vertical grids + gate All Bookmarks

**Status:** approved (conversation 2026-08-04)  
**Goal:** History and Watchlist browse like bookmark-folder grids; hide All Bookmarks until ready.

## Behavior

- **History:** vertical `LazyVGrid`, poster column count, landscape cards by default (shorter tiles). Prefer `media.thumbnail` for the still when present (no new API). Paginate `/v1/history`. macOS **View** menu toggles Landscape / Posters (`@AppStorage`); no toolbar yet.
- **Watchlist:** same vertical poster grid; no layout toggle; API has no pagination.
- **Bookmark folders:** keep vertical grid; wire load-more when pagination is present.
- **All Bookmarks:** `FeatureFlags.allBookmarksEnabled = false` — no tab, no overview fetch.

## Non-goals

- iOS/tvOS layout menu / toolbar
- Redesigning folder shelves on Library (iPhone Library tab)
