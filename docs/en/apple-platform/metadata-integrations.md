# Metadata integrations

Platform-level notes on talking to these services. The *architecture* they plug into —
aggregator behind our own API, identity mapping, provenance, trust rules — is
[policies/metadata-architecture](../policies/metadata-architecture.md); per-provider capability
sheets are [providers/](../providers/README.md).

## Evergreen

- Matching is free via `MediaItem.imdb` and `MediaItem.kinopoisk`. TMDB `/find`, Trakt, IntroDB, and
  Kinopoisk Unofficial all accept these IDs — prefer ID match over title fuzzy match.
- **TMDB** (via our Cloudflare worker proxy): cast photos, character names, title logos, episode air
  dates, tagline, budget/revenue, companies/networks, trailers. `append_to_response` keeps card
  enrichment to one HTTP round trip.
- **Kinopoisk Unofficial** (per-user key) + **keyless kpapp.link proxy**: awards, facts, stills,
  reviews, RU character names. Free tier ~500 req/day per key; proxy can die — sections hide when empty.
- **Trakt** can supply `next_episode` progress — useful later for Continue Watching accuracy, but
  needs scrobbling commitment.
- kino.pub API docs at [kinoapi.com](https://kinoapi.com) are incomplete; pin real JSON with decode
  tests when shapes matter (`HistoryEntry` wide posters, etc.).

## Project decisions

- External enrichment is a mid roadmap stage; **KinoPub catalog completeness** (collections, similar,
  photos, people, native metadata) comes first.
- Recommendations are an **explicit gap** today — do not pretend personal recs exist. Editorial tops
  (IMDb lists, etc.) are exploratory and source-constrained (dumps lack "this week" editorial lists).
- Preserve all useful kino.pub payload fields (quality, AC3, age, artwork variants) even before UI
  chips exist — decode first, display later.
- Stream survey informs engine choice; it does not unilaterally erase capability badges the user
  wants when item/device flags support them.

## Needs validation

- Premiere dates / deeper person bios from Kinopoisk.
- Reviews UI section (data may already be on `TitleMetadata`).
- Shared backend "donate" of Kinopoisk pulls — postponed; no backend yet.
