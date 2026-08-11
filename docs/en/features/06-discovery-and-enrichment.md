# 06 — Discovery and enrichment

**Status:** Partial (TMDB + Kinopoisk plumbing exists; UI gaps remain)  
**Goal:** External metadata, reviews, artwork/logos/ratings polish, editorial surfaces, and a **real**
recommendations source or an honest absence.

> **Today's plumbing is an early slice, not the target shape.** The aggregator we are building —
> a crawled catalogue behind one API, keyed by our own title id, with stored identity mapping,
> per-field provenance, people as entities, and cross-service availability — is specified in
> [policies/metadata-architecture](../policies/metadata-architecture.md), staged in
> [plans/2026-08-11-metadata-service](../plans/2026-08-11-metadata-service.md), and its providers
> are catalogued in [providers/](../providers/README.md). Read the policy's "Known defects" before
> assuming any current behavior is a decision.

## Accepted behavior

- TMDB via worker proxy; Kinopoisk Unofficial per-user key + keyless proxy fallback.
- Enrichment sections hide when empty; third-party proxies may die.
- Title logos, tagline, box office, reviews get UI only when data is ready.
- Detail hero: hold the lettered title until enrichment settles; assume a logo will
  load, paint text only when there is no URL or the image fails.
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
