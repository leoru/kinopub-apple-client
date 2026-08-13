# Provider catalogue

One page per external source. **A provider is not integrated before its sheet exists.**

The sheet is written from the provider's documentation *and* from real captured responses — the docs
lie about optional fields everywhere. The point is to know everything a provider *can* give before
deciding what we take, so we never again call one endpoint out of eight (defect 4 in
[metadata-architecture](../../.claude/skills/metadata-service/SKILL.md)).

Rules of the road: [policies/metadata-architecture](../../.claude/skills/metadata-service/SKILL.md).
Integration order and hosting: [plans/2026-08-11-metadata-service](../archive/plans/2026-08-11-metadata-service.md).

## Why the sheets are the first stage

A single provider is dozens of models. IMDb's surface, as an illustration of the shape a mature
sheet has to cover — every line is at least one table:

> Title · Report · FullCast · Posters · Images · Trailer · Ratings · UserRatings · SeasonEpisodes ·
> ExternalSites · Wikipedia · Reviews · MetacriticReviews · FAQ · Awards · Top250Movies ·
> Top250TVs · MostPopularMovies · MostPopularTVs · InTheaters · ComingSoon · BoxOffice ·
> BoxOfficeAllTime · Name · NameAwards · Company · Keyword · YouTubeTrailer

Multiply by ten providers. The sheet is what keeps that from being discovered one missing field at a
time, in app code, at runtime.

## Status

| Provider | Sheet | Integrated | Notes |
| --- | --- | --- | --- |
| kino.pub | — | base source | Library, streaming, dubs, quality, account. Authoritative for those, only those |
| TMDB | **[tmdb.md](tmdb.md)** | partial (worker proxy) | Sheet written and probed live. Field inventory shows we map ~18 of 33 movie fields and 6 of 20 append slots; zero appends at season/episode/person level; `discover`, `trending`, `changes`, `search` never touched |
| Kinopoisk Unofficial | partial, `tools/kinopoisk-metadata/` | partial (user key) | **OpenAPI: `https://kinopoiskapiunofficial.tech/documentation/api/openapi.json`** — the full surface, generate the sheet from it. **500 requests/day**, so a full pass ≈ a month; import the existing pull, do not repeat it. Offline pipeline already models far more than the app calls |
| tvoe | raw pull in `tools/tvoe_data/` | no | 4 348 titles with genres/persons/videos/images. Metadata source, availability source, or both — undecided |
| Apple (uts-api) | — | no | The Apple TV catalogue API Subler uses; storefronts, shelves, images, ratings, cast, seasons. Keyless, broad, best single "where to watch" source |
| iTunes Search | — | no | Keyless, trivial, good artwork and descriptions; store coverage only |
| IMDb (public datasets) | — | no | Only free source of **per-episode** IMDb ratings. Batch dump, not an API |
| TheTVDB | — | no | Episode-level authority where TMDB is thin; Subler has a working client |
| OMDb | — | no | Cheap aggregate of IMDb/RT/Metacritic in one call |
| Trakt | — | no | Watched state, progress, recommendations. Needs user OAuth |
| Simkl / MDBList | — | no | List and rating aggregation; both appear in every comparable project |
| Shikimori / MAL / AniList | — | no | Anime, where the general sources are weakest and id mapping is hardest |
| Plex / Jellyfin | — | no | User-linked libraries, not metadata sources |

"no" means candidate, not commitment. Order is set by stage 5+ of the plan.

## Sheet template

```markdown
# <Provider>

**Auth:** key / OAuth / none. Whose key — ours (server-side) or the user's.
**Quota:** documented limit, observed limit, what happens on exhaustion.
**Coverage:** where strong, where empty. Be specific: regions, eras, media types, and the
vote-count floor below which its data is noise.
**Ids accepted:** which of imdb / tmdb / kinopoisk / tvdb / its own it can be queried by.
**Integration kind:** system (our credentials, invisible) or user (their credentials, their quota).
**Import capabilities:** what can be bulk-imported vs only fetched per title — dumps, list exports,
OAuth-scoped user data.
**Images:** are the origin URLs stable, or do they carry a release/hash segment that breaks
re-crawls? This decides link-vs-snapshot.

## Endpoints

| Endpoint | Returns | We take | We skip, and why |
| --- | --- | --- | --- |

## Models

Field by field, with observed types and nullability — not documented ones. Note fields that are
documented but always empty, and fields that exist but are undocumented.

## Quirks

Encoding, HTML in text fields, placeholder image URLs, silent truncation, pagination lies, what a
`language`/`country`/storefront parameter actually changes.

## Verdict

Which fields of our merged document this provider should win, and under what conditions.
```

## Capturing responses

`tools/kinopoisk-metadata/probe.py` is the model: fetch raw JSON per endpoint into a local SQLite
cache untouched, then derive typed tables from that cache. Re-deriving then costs no quota, which
matters when a full pass takes a month, and it makes the sheet verifiable a year later.

## Reference implementations

Read before designing the equivalent piece. All are checked out under `~/Documents/GitHub/`.

| Project | Steal |
| --- | --- |
| [Subler](https://github.com/SublerApp/Subler) | `Classes/MetadataImporters/` — Apple `uts-api`, iTunes Store, TheTVDB, TMDB clients, and a clean `MetadataResult` map. The reference for "one Apple call answers almost everything" |
| [CrossWatch](https://github.com/cenodude/CrossWatch) | Provider matrix and sync semantics across Plex/Jellyfin/Emby/Trakt/Simkl/AniList/MDBList: watchlists, ratings, history, progress, rewatches, scrobbling |
| agregarr (`agregarr-develop/`) | **Working clients and models for ~6 services beyond TMDB** (MDBList, Trakt, MyAnimeList, Tautulli, Maintainerr, Overseerr…) — lift them and extend rather than re-deriving from vendor docs. Its 16k-line OpenAPI is also the best reference for a mature aggregator's surface: combined ratings, collections, discovery hubs, poster/overlay templates, job scheduling. It keys everything by `tmdbId`; we deliberately do not |
| [shinkro](https://github.com/shinkro/shinkro) + [shinkrodb](https://github.com/shinkro/shinkrodb) + [community-mapping](https://github.com/shinkro/community-mapping) | Community-curated cross-source id mapping — exactly our hardest problem, solved as data rather than as heuristics |
| [anibridge](https://github.com/anibridge) | Anime id mapping used as a service by other tools |
| [Film-Glance](https://github.com/FilmGlance/Film-Glance) | Nine rating platforms (RT critics+audience, Metacritic critics+user, IMDb, Letterboxd, TMDB, Trakt, Simkl) normalized to one scale, plus awards and tops. **Its README's integration post-mortem — which APIs were easy, which are flaky — is the cheapest evidence available for picking rating sources.** Read it before choosing. Stack (verified 2026-08-11): Supabase as primary DB, VPS for crawler/importers, Vercel for the app, Cloudflare DNS; RapidAPI as the multi-rating aggregator; video reviews fall back Piped → Invidious with 3 instances each and 8s timeouts; 30-day normalized cache + SWR + a daily cron refreshing the 25 most-popular expired entries |
| Plozz (`~/Documents/GitHub/Plozz`) | Module-per-concern Swift Package layout with a `MediaProvider` abstraction and one service module per external service. Right instinct, mirrored problem — see the plan's structure section for what applies to us and what does not |
