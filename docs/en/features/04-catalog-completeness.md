# 04 — KinoPub catalog completeness

**Status:** Partial  
**Goal:** Surface what kino.pub already provides — collections, people, photos, similar/related,
payload metadata — before chasing external enrichment or advanced subtitles.

## Accepted behavior

- Detail pages show available native metadata and related rails without pretending we have personal
  recommendations.
- Collections UI uses existing `CollectionsService` (`GET /v1/collections`, `/view`).
- Similar items rail stays (`GET /v1/items/similar`) — prefer this over "same genre" approximations.
- People / cast / crew routes stay first-class.
- Photos / stills when the API or already-wired proxy provides them.
- Decode and preserve quality / AC3 / age / artwork fields even before every chip is designed.

## Checklist

- [x] Similar items rail
- [x] Cast/crew → person credits pages (kino.pub actor/director queries)
- [x] Detail shelves: more from director / more with actor (`LibraryFilter.person`, first credit)
- [x] Multi-country, ratings, synopsis panel, info/audio columns
- [ ] Collections browser + collection detail UI
- [ ] Trailers as a proper detail section (hero takeover alone is not enough)
- [ ] Vote (`GET /v1/items/vote`) + show own vote state
- [ ] Wire remaining filter chips (4K/HD/AC3/KP/IMDb min — client-side facets exist)
- [ ] Concert / special tracklists when present in payload
- [ ] Explicit **recommendations gap**: document that personal recs are absent; do not fake them
- [ ] Comments endpoint — optional, community has it; port only if we commit to UI

## Out of scope here

External TMDB/Kinopoisk polish → [06-discovery-and-enrichment.md](06-discovery-and-enrichment.md).
Editorial IMDb tops → same.
