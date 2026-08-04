# 06 — Discovery and enrichment

**Status:** Partial (TMDB + Kinopoisk plumbing exists; UI gaps remain)  
**Goal:** External metadata, reviews, artwork/logos/ratings polish, editorial surfaces, and a **real**
recommendations source or an honest absence.

## Accepted behavior

- TMDB via worker proxy; Kinopoisk Unofficial per-user key + keyless proxy fallback.
- Enrichment sections hide when empty; third-party proxies may die.
- Title logos, tagline, box office, reviews get UI only when data is ready.
- Personal recommendations require an explicit source/model — until then, say we don't have them.
- Editorial tops (IMDb lists, etc.) are exploratory and source-constrained.

## Checklist

- [x] TMDB cast photos / characters / logos / air dates plumbing
- [x] Kinopoisk awards / facts / stills / RU names (keyed + proxy)
- [ ] Reviews UI section
- [ ] Surface TMDB tagline / box office / company logos
- [ ] Kinopoisk premiere dates / box office wiring
- [ ] Deeper person-bio enrichment (deferred id strategy)
- [ ] Decide recommendations approach (Trakt scrobble, local taste, editorial-only, or none)
- [ ] Editorial Home rows if a legitimate source is chosen
- [ ] Shared backend "donate" of Kinopoisk data — postponed (no backend)

## Notes

Fold former README Phase C½ / D detail here. Keep tools under `tools/kinopub-snapshot/` and
`tools/kinopoisk-metadata/` as offline helpers, not app requirements.
