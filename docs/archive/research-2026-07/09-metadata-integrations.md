# 09 — External metadata sources: Trakt, TMDB, Kinopoisk Unofficial

Condensed English summary of a 2026-07-25 research pass into what these three services (plus
IntroDB, AniSkip, and IMDb's non-commercial datasets) can give the app, verified by live requests
and official docs where marked. Current status of this integration work is tracked in
[`06-discovery-and-enrichment.md`](../../../ROADMAP.md) — this archive
is the original research, not the current roadmap. Russian original: `09-metadata-integrations.ru.md`
(gitignored, local only).

## TL;DR (at the time)

- **Matching is already free.** `MediaItem.imdb` and `MediaItem.kinopoisk` open TMDB
  (`/find/{id}?external_source=imdb_id`), Trakt (paths accept an IMDb id directly), IntroDB
  (`?imdb_id=`), and Kinopoisk Unofficial (`?imdbId=`) — none require title-matching.
- **TMDB closes almost every visual gap**: cast photos + character names, **title logos** (exactly
  what Apple TV substitutes for text titles), episode air dates, `next_episode_to_air`, age ratings,
  trailers. Free key for non-commercial use, ~50 rps, `append_to_response` batches up to 20
  sub-requests — one detail card costs one HTTP request.
- **Trakt closes "next episode."** `GET /shows/{imdb_id}/progress/watched` returns `next_episode` —
  the direct fix for "Continue Watching shows the last-*played* episode" instead of the next
  unwatched one. But it only knows what's been scrobbled to it — it requires standing up scrobbling
  first, and won't be accurate until then.
- **Trakt scrobbling maps almost for free onto the existing player.** The app already has a
  10-second time observer and a play/pause rate observer — the same two points that send kino.pub's
  own watch-mark calls can send Trakt's `/scrobble/start|pause|stop`.
- **Awards, premiere dates, box office, and Russian text are Kinopoisk-Unofficial-only.** Every one
  of its 25 documented endpoints requires an API key — nothing works keyless there, closing an open
  question the app's own roadmap had left unanswered.
- **Skip-intro is solvable today, keyless.** IntroDB (`api.introdb.app/segments?imdb_id=&season=&
  episode=`) returns intro/recap/outro timecodes with no authorization — verified live.
- **Client-side keys are only honestly safe behind a proxy.** A TMDB read-token in `Info.plist`
  survives until the first person opens the `.ipa`; a Trakt `client_secret` is worse, since it lets
  someone impersonate the app against a user's account.
- **The existing `APIClient` can't take a second source as-is.** Two real defects: it never checks
  HTTP status (Trakt's device-code flow distinguishes states *only* by status code), and its plugin
  chain is built with a broken `reduce` that silently drops every plugin but the last.
- **Recommended architecture: a separate `KinoPubMetadata` package**, not an extension of
  `KinoPubBackend` — different error contracts, different pagination schemes (Trakt paginates via
  headers), and a cache layer `KinoPubBackend` doesn't have and shouldn't grow.
- **Legal requirements are simple but non-optional.** TMDB needs its logo (smaller than the app's
  own) plus "This product uses the TMDB API but is not endorsed or certified by TMDB." in
  About/Credits; watch-providers data separately needs JustWatch attribution. Trakt requires caching
  every image (no hotlinking). IMDb's datasets are personal-non-commercial only.

## What each source gives, and what it costs

**TMDB** (v3, bearer auth preferred over query-param key — doesn't leak into logged URLs): cast
photos and character names via `/credits`/`aggregate_credits`; **title logos** via `/images` →
`logos[]`; episode air dates via `/tv/{id}/season/{n}`; `next_episode_to_air` for schedule badges;
age ratings via `/release_dates`/`content_ratings`; trailers (YouTube keys — **not directly
playable in `AVPlayer`**, so kino.pub's own trailer URL stays the only working hero-trailer source).
IMDb-id matching via `/find/{id}?external_source=imdb_id`. Russian localization via `language=ru-RU`
works on overview/title/genre fields but **not** on `character` names, which TMDB stores in
whatever language the credit was entered (usually English) — this is the specific reason Kinopoisk
Unofficial stays necessary even with TMDB in place. Rate limit is informally ~40-50 rps with no
documented `Retry-After` header, effectively never a constraint at this app's request volume.

**Trakt** (device-code OAuth, same shape as the app's existing kino.pub flow): scrobble endpoints
(`start`/`pause`/`stop`, all OAuth-required POST, progress expressed as 0-100%, not seconds) — a
scrobble of >80% counts as watched, 1-79% is treated as pause-and-resume, <1% is rejected with 422.
`GET /shows/{id}/progress/watched` (accepts an IMDb id directly) returns `next_episode` — the fix
for stale Continue Watching, but its accuracy depends entirely on scrobbling already being live and
the user's watch history already being synced. `GET /sync/progress/watched` gives progress for an
entire watchlist in one call rather than one request per show — important for a Home screen.
Curated lists (`/lists/trending`, `/movies/boxoffice`, `/shows/anticipated`) are the recommended
source for any future "top charts" feature — genuinely better than scraping IMDb's datasets, which
contain no editorial lists at all. Rate limits: 1 POST/sec per authed user (the real constraint for
scrobbling — needs debouncing against seek/pause flapping), 1000 GET/5min otherwise.

**Kinopoisk Unofficial** (`X-API-KEY` header, quota checkable live via
`/api/v1/api_keys/{key}`, exact numbers not published — informally ~500/day, ~10/sec): the only
source for Russian character names (`/staff` → `description` field), awards, premiere dates by
country, box office, and Russian episode titles/dates. An unofficial, single-maintainer service —
anything built on it must degrade to current behavior (initials instead of a photo, a hidden awards
section) rather than break the page, matching the app's existing pattern for its similar-items
section swallowing errors.

**IntroDB** (keyless read, `imdb_id`+`season`+`episode` — exactly what the app already has):
verified live, returns intro/recap/outro timecodes with confidence scores — closes skip-intro
without any subtitle-gap heuristic. Coverage for Russian-heavy or niche content is unverified
(community-driven database).

**AniSkip**: verified live, but keyed by MyAnimeList/AniList id, which the app has no bridge to from
IMDb — deprioritized unless anime becomes a meaningful share of usage.

**IMDb non-commercial datasets**: real and current, but personal-non-commercial license only, and
contain **no editorial "top 10" style lists** — Trakt's curated-list endpoints are the actual
recommended source for that use case; the datasets aren't worth shipping in the app at all.

## The `APIClient` gaps that block a second source

Two concrete defects, both fixable in a few lines: `performRequest` never inspects HTTP status
before decoding — Trakt's device-code polling distinguishes `400`/`404`/`409`/`410`/`418`/`429`
*purely* by status code, so this is a hard blocker, not a nice-to-have; and the plugin-composition
`reduce` call feeds every plugin the *original* request instead of threading the accumulator, so
only the last plugin's changes survive — currently invisible because there's only one auth plugin in
production, but would silently break the moment a second one (Trakt headers) is added.

## The metadata architecture: `KinoPubMetadata`, not `KinoPubBackend`

Rationale: `APIClient` is single-base-URL by design (three sources need three instances, defeating
"one client"); each source has an incompatible error contract (`BackendError` vs. TMDB's
`status_message` vs. Trakt's empty-body-plus-status); Trakt paginates via response headers, which
none of the existing plumbing surfaces; and `KinoPubBackend` is meant to stay portable upstream code
shared with the community fork — the less non-kino.pub code lives there, the easier that stays true.

Core design principle for merging sources: **kino.pub is always the base; external sources only fill
gaps that are empty, never overwrite what kino.pub already provided** — Rivulet explicitly avoided
letting a page visibly change moments after opening as external data arrived, and this app's plan
followed the same rule. A `MetadataSource` protocol with default "I don't know this" implementations
per capability, an actor-based `MetadataService` fanning out to all configured sources concurrently
via `withTaskGroup` and merging whatever came back (failures drop silently, they don't block other
sources), and a field-by-field merge priority table (Kinopoisk's Russian character name before
TMDB's English one; TMDB's logo before Kinopoisk's; kino.pub's own "next episode" call before
Trakt's, since it works for the whole catalog without requiring auth or synced history first).

## Keys without a backend: the realistic options

Any key that reaches the device is effectively public — `strings` finds it in the binary. The
practical breakdown: TMDB's read-token is low-stakes enough for a personal build to accept directly
in `Info.plist`, but a **proxy** (a Cloudflare Worker, per Rivulet's example) is the only way to
avoid distributing it at all, and usefully adds edge caching for TMDB responses too. Trakt's
`client_id` isn't secret (it's sent in every request header anyway) but its `client_secret` — needed
only at the device-code token-exchange step — must go through a proxy; the resulting tokens
themselves live in Keychain and all other Trakt calls go direct. Kinopoisk Unofficial's key should
be **user-supplied** (a Settings field, stored in Keychain) rather than shared, since its quota is
small and per-account — a shared key would exhaust in a day. IntroDB and AniSkip need no key at all.

## Caching and offline behavior

Three mechanisms treated as non-negotiable: **in-flight deduplication** (hero, cast section, and a
row card can all request the same item concurrently — one request, not three), **caching negative
results** ("no logo," "not found in TMDB," "IntroDB has no data for this episode") as a valid,
cacheable answer distinct from a transient network error (which must not be cached), and **task
cancellation on navigating away** (the app's `MediaItemModel` at the time created bare `Task {}`
work that didn't cancel — tolerable for kino.pub's own three lightweight calls, not for a dozen
external ones). Suggested TTLs: id-matching results forever (ids don't change); artwork/cast paths
30 days; past-season episode dates forever, current-season dates and `next_episode_to_air` 12 hours
(the whole point of fetching them); Trakt's `progress/watched` never cached beyond the session (it's
live user state); Trakt's `sync/last_activities` 5 minutes as a cheap "did anything change" check.
Metadata is decoration, not a dependency — offline, a card must render exactly as it does today
(initials, no dates, no logo), never a "loading metadata" spinner.

## Open questions this report left unverified

Whether `MediaItem.imdb`'s numeric value actually maps to a `tt<7-digit>` IMDb id the way assumed
(flagged as the single most load-bearing thing to verify first — everything else in the report
depends on it); what fraction of the kino.pub catalog even has a non-null `imdb`/`kinopoisk` id
(determines whether Kinopoisk becomes the *primary* source rather than a supplement); Kinopoisk
Unofficial's actual rate limits (only discoverable live via its quota endpoint, not published);
completeness of TMDB's Russian localization across this app's specific catalog; whether TMDB's
`append_to_response=season/N` syntax (seen in community examples) is actually supported; whether
TMDB title logos ever ship as SVG (which `AsyncImage` can't render); Trakt's actual token lifetime
(the docs text says 7 days, a response example shows `86400` seconds — treat the response's
`expires_in` as authoritative, not either stated constant); whether `DCAppAttestService` is
supported on tvOS at all (Rivulet uses App Attest on tvOS 26, suggesting yes, but this wasn't
independently confirmed against Apple's docs); and IntroDB's real coverage for this catalog's actual
content mix — recommended to sample 20-30 real IMDb ids from watch history and measure hit rate
before building a feature on top of it.
