# Community parity port — sections, filters, settings

> **Archived 2026-08-13.** Survived: this inventory of what the community fork surfaces and we do
> not — it is the reason to keep the file. The 31 open items are condensed into ROADMAP stage 4
> ("Catalog parity with the community fork"); tick them there, not here.


**Opened:** 2026-08-05
**Scope:** everything the community fork (`dungeon-master-xx`, read-only remote `community`) already
surfaces that we do not — Home/For-You shelves, catalog sections, collections, filter facets, and the
Settings screens behind them.
**Not scope:** their UI. Per [community-fork](../../community-fork.md) this is a **technical steal**:
we take endpoints, parameter shapes, genre ids and section taxonomy, and render them with our own
rows / focus / materials (`MediaRowsView`, `ContentStore`, `MediaCard`).

Checkboxes here are working state. When an item lands, tick it **and** tick the owning line in the
feature doc it belongs to (02 / 03 / 04) — that stays the living checklist.

---

## Inventory: what they have vs. what we have

| Area | Community | Us |
| --- | --- | --- |
| Home shelves | 9 typed shelves mirroring the web home (`Views/Home/HomeModel.swift`) | 6 shelves: hot/fresh/popular × movie/serial ([HomeCatalog.swift:27](../../../KinoPubAppleClient/Views/Main/HomeCatalog.swift)) |
| Catalog sections | 6 content types + 5 genre presets (cartoons, cartoon series, anime, stand-up, 3D) in sidebar/tabs (`NavigationTabs.swift`) | Movies + Series tabs only |
| Collections | Full browser + detail (`Views/Collections/`) | Home row + browser + detail ([Views/Collections/](../../../KinoPubAppleClient/Views/Collections/)); sidebar entry still open |
| New episodes | Dedicated screen, tabs New episodes / My series, type sub-tabs (`Views/Watching/`) | Watchlist row inside Library only |
| More from director / with actor | Two shelves on the detail page (`MediaItemView.swift:933`) | Detail shelves landed (`MediaItemPersonShelfSection`); person-page any-credit merge still open |
| Filters | Sheet with genre, country, year range, KP/IMDb sliders, HD/4K/AC3 toggles (`Views/Main/Filter/`) | Model has every facet; bar exposes sort/type/genre/country/year only ([LibraryFiltersBar.swift](../../../KinoPubAppleClient/Views/Search/LibraryFiltersBar.swift)) |
| Device settings | Real form: stream type, server location, 4K/HEVC/HDR, Save (`Views/Profile/Device/`) | `@State` demo with no persistence ([PlaceholderSettingsPanes.swift:37](../../../KinoPubAppleClient/Views/Settings/Panes/PlaceholderSettingsPanes.swift)) |
| Devices list | `DevicesView` | Service only (`ListDevicesRequest`, `RemoveDeviceRequest`) |
| Section visibility | Profile → Sections toggles (`SectionVisibilityStore`) | None |
| Storage / quality cap / language | Storage breakdown sheet, `StreamQuality` cap, in-app language picker | None (language via system) |
| TV / Sport + EPG | `Views/Sport/`, `Services/EPG/` (XMLTV) | `TVChannelsRequest` in backend, no UI |
| Comments | `Views/Comments/CommentsView.swift` | Not ported (open decision in feature 04) |

## API facts worth keeping (verified by them, re-verify before load-bearing use)

- `/v1/items` honors **server-side**: `type`, `genre`, `country`, `year`, `sort`, `period`,
  `director`, cast. It **ignores** `imdb` / `kinopoisk` / `quality` / `conditions` — those stay
  client-side facets, which is exactly what [LibraryFilter](../../../Packages/KinoPubBackend/Sources/KinoPubBackend/Models/LibraryFilter.swift) already does.
- `genre` and `country` take **comma-separated lists**. We send a single id today.
- `type` takes a comma-separated list too (`movie,serial`) — that's how the Anime preset spans both.
- **Actor parameter:** docs list `[actor]`; the live mobile API filters on `cast=` (community-
  verified). We send `cast` via `MediaPerson.Role.itemsQueryParameter` while keeping the semantic
  role as `.actor`. `director=` matches the docs.
- Genre-preset ids (from their live web-app capture): **cartoons** = `movie` + genre `23`,
  **cartoon series** = `serial` + genre `23`, **anime** = `movie,serial` + genre `25`,
  **stand-up** = `movie` + genre `101`, **3D** = `type=3d`.
- Their Home shelf specs (type + sort + period), mirroring the web home in order:
  popular movies (`views-`, `period=month`), new movies (`created-`), popular series (`watchers-`),
  new series (`created-`), new concerts, new 3D, new documovies, new docuseries, new TV shows
  (all `created-`).
- Search supports `sectioned=1` → results grouped by `type`. We don't use it.
- Genres are typed (`movie` / `music` / `docu` / `tvshow`): a concert can only hold `music` genres,
  so the genre picker must reload when the type changes or it offers impossible combinations.

---

## 1. Collections — highest priority

The one place where a whole product surface is missing and the service is already built.

- [x] `CollectionsView`: paginated shelves of collections (`GET /v1/collections`), one row per
      collection with preview cards from `/v1/collections/view` (same endpoint-shape tradeoff as
      community). Sort picker still open.
- [x] `CollectionDetailView`: `GET /v1/collections/view` → items grid via `ContentItemsListView`
- [x] Routes: `Route.collections` / `.collection(Collection)` + `RouteDestination` cases; Home row
      entry on every platform. Sidebar / tab item still open.
- [x] One Home row "Collections" that opens the browser (title-tap → full screen, per `MediaRow.destination`)
- [x] `RowKey.collections` + TTL so the row participates in `ContentStore` like every other row

## 2. Home / For You shelves

Replace the fixed hot/fresh/popular × 2 grid with the web taxonomy.

- [ ] Extend `HomeCatalog.Shortcut` into a spec carrying `type` + `sort` + `period` (their `ShelfSpec`),
      so a shelf is any `/v1/items` query, not just a shortcut endpoint
- [ ] Port the 9 shelves above; keep the "drop empty shelves" rule we already have
- [ ] `RowKey` needs a case for filter-backed shelves (`.filter(hash)` or `.shelf(id)`) — today it
      only knows `.shortcut(MediaShortcut, MediaType)`
- [ ] Genre shelves ("Комедии", "Ужасы", …): same spec machinery, genre id from `/v1/genres`.
      Decide the source of the list — fixed editorial set vs. top-N genres — before coding
- [ ] Type shelves: concerts, 3D, documovies, docuseries, TV shows (horizontal rows, our cards)
- [ ] Every shelf header opens the matching filtered full screen (`MediaRow.destination` → catalog
      with a prefilled `LibraryFilter`) — the filtered-catalog route has to exist first (§3)

## 3. Catalog sections: content types + genre presets

- [ ] A `CatalogSection` type in our shell: content type or preset, each resolving to a `LibraryFilter`
- [ ] Port the 5 presets with their genre ids (cartoons, cartoon series, anime, stand-up, 3D)
- [ ] `LibraryFilter` needs `rawType: String?` (comma-separated `type`) for the anime preset, and
      `genreIDs: [Int]` / `countryIDs: [Int]` instead of the single-id fields
- [ ] Sidebar/tab placement per platform — do **not** grow the iPhone tab bar; extra sections go in
      a "More"-style destination or the sidebar (see §7 visibility)
- [ ] A generic "filtered catalog" screen these all push to, so shelf headers and sections share one
      destination instead of two parallel grids

## 4. New episodes / Watching

- [ ] "New episodes" screen: `/v1/watching/serials?subscribed=1` with type sub-tabs
      (`serial` / `docuserial` / `tvshow`), unwatched-episode counts on the card
- [ ] "My series" list (subscribed serials) + movies-in-progress (`/v1/watching/movies`)
- [ ] Decide placement: a Library row that opens a full screen (our Library-is-one-scroll rule,
      feature 03) rather than a new top-level tab
- [ ] Badge treatment for "N new episodes" — reuse the card caption/progress structure, no new atom

## 5. Detail page — More from director / More with actor

Their version: two shelves under Related, `sort=rating-`, best-effort, hidden when empty.

**Decided 2026-08-05 — where the role filter belongs:**
- **Item detail page: filter by role.** "More from <director>" is the `director` query, "More with
  <actor>" is the actor query. Two separate shelves, each narrowed to what that person did *in that
  capacity* — that's what makes the pair read as two different rows instead of one repeated list.
- **Person page: do not filter by profession.** One page per name showing everything kino.pub has
  under it — directed *and* acted — merged into a single grid, not split into "as director" /
  "as actor" sections and not narrowed to whichever credit the user happened to tap.

- [x] Add both shelves to `MediaItemDetailSections` beside the existing Similar rail
- [x] Reuse `LibraryFilter.person` — query key is `cast` / `director` via
      `MediaPerson.Role.itemsQueryParameter`
- [x] Cap to the first credited director / first billed actor (their heuristic) unless the design
      says otherwise; title taps push `PersonItemsView`
- [x] Skeleton row while loading, drop the section entirely on empty — same rule as enrichment sections

### Person page follow-through (ours, not a port)

Today `PersonItemsView` is the *role-filtered* listing: `LibraryFilter.person` carries a
`MediaPerson.Role`, and `MediaPerson`'s `id` / `==` / `hash` all fold role in — so Cameron-as-director
and Cameron-as-actor are two different pages. That has to change:

- [ ] `LibraryFilter.person` gains a mode: role-scoped (detail shelves) vs. **any credit** (person page)
- [ ] Any-credit mode issues both queries and merges by item id, deduped, re-sorted by the active
      sort. Credits lists run to a few pages at most, so fetching both fully and sorting locally is
      acceptable — but check the page counts before committing to it
- [ ] `MediaPerson` identity keys on the **name**, not `role:name`. Role stays as a display hint
      (which section the tap came from) and as the shelf's query, not as identity — otherwise the
      same person keeps minting separate routes and separate cache entries
- [ ] Re-check `RouteDestination`'s `"person-\(person.id)"` key and any zoom-transition ids that
      currently depend on role being part of that string

## 6. Filters — expose what the model already supports

The model is ported; the chrome isn't. Nothing here needs backend work.

- [ ] Period menu (day/week/month/year) — `CatalogPeriod` is already sent server-side, the `DESIGN:`
      note in `LibraryFiltersBar` has been waiting for this
- [ ] Kinopoisk / IMDb minimum-rating controls (0…10, 0.1 steps)
- [ ] HD / without-HD / 4K / AC3 toggles
- [ ] Multi-select genres and countries (needs the array fields from §3)
- [ ] Active-facet count badge + "Clear" (we have Clear, not the count)
- [ ] Year: keep our decade ranges for the remote; consider from/to pickers on iOS/macOS only
- [ ] Genre list reloads when the type changes (typed genres, see API facts)
- [ ] tvOS: menus, not a sheet — the existing bar is the right pattern; only the iOS/macOS variant
      may become a sheet
- [ ] Not ported yet, decide: `subtitles`, `language`, `translation`, `age`, `letter`, `finished`
      (their model carries them; several are ignored by the mobile API — verify before adding chrome)

## 7. Settings — port the real panes

**Already covered, not gaps** (checked 2026-08-05, don't re-port): user info block (name /
subscription / registration / app version — `GeneralSettingsPane.swift`,
`TVProfileSettingsView.swift`), in-app language picker with the same restart-alert pattern
(`ProfileModel.changeLanguage`), and the max-streaming-quality cap (`PlaybackSettingsPane`'s
"Stream quality" picker, `StreamQuality`). The earlier draft of this doc listed these as gaps —
they weren't; verify against current code before trusting old drafts of this section.

**Real gaps:**

- [x] **Device settings** pane replaces the `@State` demo in `PlaceholderSettingsPanes.swift`
      (`DevicesSettingsPane`, under `SettingsCategory.devices`): stream type + server location
      pickers fed by `DeviceSettings.streamingTypeOptions` / `serverLocationOptions`, 4K / HEVC /
      HDR toggles, explicit Save, "changes take effect within a minute" footer.
      `DeviceService.fetchSettings` / `updateSettings` already exist. Keep our `mixedPlaylist`
      toggle (HDR/HEVC fallback note in `DeviceSettings`) — theirs doesn't have it, and dropping it
      reintroduces the HEVC-only-HDR-master bug (-11868/-17223)
      — landed 2026-08-05: real pane moved to `Views/Settings/Panes/DevicesSettingsPane.swift`.
- [x] **Devices** list + remove: `DeviceService.listDevices()` / `removeDevice(id:)` are already
      implemented (the protocol comment literally says "Settings UI is DESIGN TBD") — the current
      pane instead hardcodes two fake rows ("Living Room" / "MacBook"). Push via a new
      `SettingsDetailRoute` case from the Devices pane, current device marked, confirm before remove
      — landed 2026-08-05: `Views/Settings/DevicesListView.swift`, pushed from the new Device
      settings pane via `SettingsDetailRoute.devicesList`.
- [x] **Storage**: report what's actually introspectable today — `RowSnapshotStore` disk snapshots,
      the `tmp/kinopub-hls` scratch directory ([playback conveniences](../../../ROADMAP.md)
      already flags it as never cleaned up), the Downloads folder when
      `FeatureFlags.downloadsEnabled`, system `URLCache`. No unified image cache exists yet (feature
      01 item, not done) — don't invent a number for it. "Clear" only touches what's safely
      disposable (snapshots, HLS temp files, URLCache) — never a download the user hasn't finished
      watching, never Keychain
      — landed 2026-08-05: `Views/Settings/StorageSettingsView.swift`, pushed from Advanced via
      `SettingsDetailRoute.storage`. No image-cache row, as specified.
- [x] **Sections** pane: persisted show/hide store + toggle screen (§8). Scope this pane's *first
      cut* to what already exists in the shell; do **not** touch `TabsNavigationView.swift`'s tab/
      sidebar switch to wire actual hiding in this pass — that file is also where the §1/§3 catalog
      entry points land, and two unrelated changes to the same switch statement is exactly the kind
      of collision this doc exists to avoid. Wire the store into real hide/show behavior once the
      catalog-sections work (§3) lands and needs it anyway
      — landed 2026-08-05: store + `Views/Settings/SectionsSettingsView.swift`, pushed from
      Appearance via `SettingsDetailRoute.sections` (tab-bar/sidebar visibility fits there, not
      General). `TabsNavigationView.swift` untouched; the toggle screen says outright that hiding a
      section doesn't do anything yet.
- [ ] Feature-gate every pane that stays a stub instead of shipping fake toggles — still open for
      Downloads/Sidebar/Notifications/Backups/Network, untouched by this pass

## 8. Section visibility

- [x] Persisted show/hide for catalog sections (their `SectionVisibilityStore`, `UserDefaults`) —
      `States/Navigation/SectionVisibilityStore.swift`
- [x] Forced-visible set: Movies, Series, Collections — Movies/Series forced; Collections isn't a
      real destination yet (§1), so it isn't in the set until it exists
- [x] Settings → Sections toggles, grouped Library / Other
- [x] Check against the `TabViewCustomization` ceiling noted in [local-caching](local-caching.md)
      before designing sidebar-side customization — it's mac-only and `@available(tvOS,
      unavailable)`, so the store is a plain cross-platform `UserDefaults` set instead of building
      on it

## 9. Bugs to fix alongside

- [ ] **Season rail scroll is broken** — reported 2026-08-05, not yet diagnosed.
      [SeasonsRailView.swift](../../../KinoPubAppleClient/Views/MediaItem/Subviews/SeasonsRailView.swift)
      owns tab-driven scrolling (`isScrollingFromTab`), scroll-to-first-unseen (`didScrollToUnseen`)
      and focus sync; the regression is in one of those three
- [ ] **iOS hero layout** — user-flagged 2026-08-05 as visibly broken. Feature 01 already tracks
      the two concrete items (`MediaItemHeroView` shared `.focused` across four buttons; hero height
      via `containerRelativeFrame` instead of hard-coded values). **Blocked: needs a design spec
      before handing to an agent** — do not spawn this as a standalone task off a code read alone,
      the ask specifically requires a visual spec first. Stays on this list so it isn't lost, not
      because it's actionable right now.

## 10. Deliberately not ported yet

- **TV / Sport + EPG.** They ship an XMLTV client with its own cache and channel matching. We have
  `TVChannelsRequest` and nothing else. This is a feature, not a port — needs its own decision.
- **Comments.** Endpoint is trivial; the open question is whether we commit to the UI (feature 04).
- **Their Home hero carousel.** Ours is gated behind `FeatureFlags.homeBannerEnabled` by design.

---

## Suggested order

1. ~~Collections (§1)~~ — Home row + browser + detail landed; sidebar entry / sort picker still open
2. Filter chrome (§6) — pure UI over a model that's already ported
3. ~~Device settings + Devices (§7)~~ — landed (real Device pane, Devices list, Storage, Sections)
4. Shelf-spec refactor + Home shelves + type/genre sections (§2, §3) — one machinery, do it once
5. ~~More from director / with actor (§5 detail shelves)~~ — landed; person-page any-credit
   follow-through still open
6. New episodes (§4) — section visibility (§8) also landed

§9 is not in this order — the rail scroll regression jumps the queue.
