# Media card context menu — single source

**Date:** 2026-08-04  
**Status:** Approved direction; phase 1 first

## Goal

One builder owns every card context-menu item (ids, titles, icons, grouping). Call sites only pass a `MediaCard` plus the handlers / capabilities they support. Items appear or vanish from that input — no duplicated menu trees on Home rows, banners, episode rails, or later surfaces.

## Scope

Applies to:

- Continue Watching (landscape)
- Vertical catalog posters
- Home banners (`HomeBannerCardView` links)
- Episode rails (already use `MediaCardContextMenus`)

Not in phase 1: Play, watchlist toggle, bookmarks submenu, Share, Download wiring, macOS icon-visibility polish beyond what the shared builder already emits.

## Single source

`MediaCardContextMenus` (app target) remains the only place that defines:

- action `id`s
- localized titles
- SF Symbol names
- button roles
- logical `Divider` groups (when the model supports sections)

Call sites pass optional handlers / flags. A missing handler means that item is omitted. No second copy of keys/icons in `MainView`, banner code, or seasons.

`KinoPubUI` stays presentation-only: `MediaCardContextAction` (+ section/divider support if needed) and `MediaCardContextMenuModifier`. Banners use the same `contextMenuProvider` as shelf cards.

### Image URL for debug

Displayed artwork URL matches what the card paints:

- landscape / CW: `landscapeImageURL ?? posterURL`
- poster: `posterURL`
- banner: prefer the backdrop/wide URL the banner actually loads (`backdropURL` / wide fallback chain), else poster — same string the banner view would request first for the dominant still, documented in the builder helper so debug matches reality

## Phase 1 (shipped)

1. Remove the Home `guard card.isLandscape` so vertical posters can get a menu.
2. Apply `contextMenuProvider` to banner `NavigationLink`s in `MediaRowsView` (same provider as rows).
3. Comment out **Browse Recently Watched** / **Browse My Watchlist** in the shared builder (both CW and seasons inherit that).
4. `#if DEBUG`: append a trailing item whose title is the full image URL; action opens it via `openURL` / platform browser. Omit if URL string is empty / unparseable.
5. **Download:** do not show. Leave a `TODO` next to `FeatureFlags.downloadsEnabled` (and/or the builder) that Download will join the shared menu when downloads ship. No stub menu row.

## Phase 2 (shipped)

Full menu from the same builder, no stubs:

| Group | Items |
| --- | --- |
| Playback | Play (fetch details → player) |
| Navigation | Go to Show / Movie |
| Library | Add/Remove Watchlist (series); Add to Bookmarks ▸ folders (checkmark when contained) |
| Watched | Mark as Watched / Mark as New — CW/episodes always when video known; catalog **movies only** |
| Destructive | Remove from Recently Watched (CW) |
| Debug | image URL (`#if DEBUG`) |

Separators between groups. macOS menu rows use explicit `Image` + `Text` so icons stay visible. `MediaCardMenuCoordinator` owns network side effects; `NavigationState.push` targets the selected tab stack.

## Later

1. Download item gated by `FeatureFlags.downloadsEnabled`.
2. Optimistic `isInWatchlist` / `isWatched` flips on catalog cards.
3. New Folder from the bookmarks submenu.
4. Future: Hide and similar.

## Non-goals

- Decorative ⋯ buttons on cards (policy: long-press / secondary-click only).
- Third-party share chrome until Share is a real handler.
- Inventing watchlist UI that collides with Mark as Watched without an explicit product pass (watchlist is a separate labeled action when wired).

## Validation

- DEBUG build: secondary-click / long-press CW, a vertical poster, and a banner (when banner flag on) shows the image URL; choosing it opens the browser.
- Release / non-DEBUG: no image URL row.
- Browse my… rows absent.
- No Download row while `downloadsEnabled` is false.
- Episode rail and Home both compile against the same builder API.
