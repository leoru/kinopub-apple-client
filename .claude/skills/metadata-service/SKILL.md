---
name: metadata-service
description: Working on external metadata, enrichment, providers (TMDB, Kinopoisk, Trakt, tvoe), the Cloudflare workers, the crawl/ingest tools, artwork resolution, person/credit matching, ratings, or anything under KinoPubMetadata. Use before adding a provider, a field, an app-side network client, or a cache keyed on a provider id.
---

# Metadata architecture

**Durable design law**, and which shortcuts are forbidden because they lead somewhere we have
already decided not to go. Today's implementation (`Packages/KinoPubMetadata` + `workers/tmdb-proxy`)
is an early slice, **not the shape of the finished thing** — read "Known defects" before assuming a
behavior is intentional. Per-provider capability sheets: `docs/providers/`.

## Product intent

We are building **an encyclopedia with a Plex-shaped layer on top**, which happens to stream through
kino.pub. Their contribution is a library, an account, and video delivery. Everything a user looks at
before pressing play is ours: artwork, credits, tags, collections, similars, ratings from every
source that has them, reviews, awards, trailers, dubs, per-episode data, badges, and where else this
thing streams and in what quality.

Two consequences that settle most arguments:

- **Our catalogue is bigger than kino.pub's library.** Upcoming titles, titles that stream only
  elsewhere, and titles kino.pub dropped are first-class. A design that assumes every title has a
  kino.pub id is wrong on arrival.
- **A design that makes provider #7 cheap beats a design that makes provider #2 fast.** Field count
  grows without limit; latency budgets do not.

## Rule zero: document the source before touching it

**Before integrating a new source, and before extending an existing one, its schemas, methods and
models are written down in full** — every endpoint it offers us, every field, every model, including
ones we have no intention of using. System automation and user integrations alike.

This is not hygiene, it is what stops the migration treadmill: without it, every newly-spotted method
changes the schema again. With it, "we already saw this endpoint and decided against it" is a
recorded fact instead of a rediscovery.

Corollary, and it is deliberate: **store every detail the API offers.** What is redundant gets
decided later, from evidence — never at ingest time, never by guessing in advance. Dropping a field
at ingest costs a month of re-crawling to undo; keeping it costs bytes.

## Target architecture

### 1. The key is our own title id

External ids (`kinopub`, `imdb`, `tmdb`, `kinopoisk`, `tvdb`, `trakt`, `anilist`/`mal`, `apple`) are
**attributes with a confidence and a source**, never the primary key.

```
title(id PK, kind, original_title, year, …)
title_external_id(title_id, namespace, value, confidence, method, resolved_at)
```

Entry points `/v1/title/{id}` and `/v1/title/by/{namespace}/{value}`. **One universal method, asked
in fields:** the client says which fields it wants and gets exactly those. Whether a field came from
one source or six is our problem, visible in provenance and never in the request. The client never
names a provider, never branches on one, and never issues a second call to find out what exists.

### 2. Catalogue, not lazy cache

Crawl and hold the whole thing, refresh on a schedule, **store raw before deriving**. Raw payloads
are kept per fetch so the schema can be re-derived without re-spending quota.

Refresh cadence is per data class, not per title: identity is permanent, credits near-permanent,
ratings/popularity daily-ish, availability and "new episode" hourly for hot titles.

**Never re-crawl what already exists.** The kino.pub sweep, the tvoe pull and the Kinopoisk pulls
were paid for once, in quota and in days. The first ingest is an **import** from those dumps; live
fetching starts from what is missing. Any new bulk source is imported the same way — a crawl is the
last resort.

### 3. Two tiers; the client only sees one

| Tier | Where | Holds |
| --- | --- | --- |
| System of record | VPS, Postgres | Full crawl, raw payloads, the entity graph, jobs |
| Published read model | Edge (Workers + D1/KV) | Compact per-title documents, identity map, image map, tops and rows |

The client never queries the system of record, and the read model is never authored by hand. A full
crawl's write volume and a TV app's read latency have nothing in common and should not share a
database.

### 4. Images: the criterion is URL stability, not storage cost

- **Stable origin URL → link to it** (tvoe originals, TMDB paths).
- **Unstable URL → snapshot or proxy.** Resized/CDN-derived URLs carrying a release number or
  content hash break every re-crawl — the hash, not the megabytes, is the problem.
- **The proxy is mandatory:** `GET /img/{kind}/{size}/{namespace}/{id}` is the path the client uses,
  always. Without it the client holds only kino.pub's id — no TMDB path, so no title logo, no
  backdrop, no size variants, and no way to know an asset exists before asking.
- The document also carries the provider-canonical URL for cases that want the origin.
- **We host only assets we created**: a replacement cover, a crop, a generated logo, an extracted
  average colour.
- Per-source image notes belong in the provider sheets, because the differences are the point: Apple
  is the strongest free artwork source; tvoe supplies curated Russian material specifically —
  backdrops without lettering, Russian title logos, banner-style descriptions, its own badges.

### 5. Geography: two audiences, one API, minimal networking

kino.pub is Russia-facing and its users already live behind VPNs; TMDB is reachable directly for
everyone else. So the API answers the same way for everybody — canonical URL **plus** proxy URL —
and the client probes origin reachability **once**, remembers, and picks. That is the entire
networking complexity budget: no per-region routing, no geo logic in the worker. Non-RU clients pay
us for one JSON call and go straight to the sources. We are the index, not the pipe.

### 6. Per-field provenance and declared precedence

Merging is not "whoever answered first wins". Every field has a declared source order, and the
document records where each field came from.

| Field group | Precedence |
| --- | --- |
| Cast / crew list, order, episode counts | TMDB → Kinopoisk → kino.pub |
| Russian character and person names | Kinopoisk → TMDB translations → kino.pub |
| Title logo, backdrop, poster | Apple/TMDB (language-scored) → Kinopoisk → kino.pub |
| Awards, facts, stills | Kinopoisk |
| Dubs / voice tracks, stream quality | kino.pub — nobody else has this at all |
| Ratings | **All of them, side by side, never silently averaged** |
| Availability, deeplinks | Per-service, each with its own `checked_at` |

### 7. Trust is a function of the title, not the provider

- Do **not** trust kino.pub's baked-in credits for anything with an international match — five names
  on a thirty-season show are frequently stale junk.
- Do **not** trust Kinopoisk credits for a non-CIS title below a vote-count threshold.
- **Always ask the international source, including for Russian titles** — it returns more per credit
  (episode counts, department, ordering, popularity) even when the RU source has the title.
- Ratings from a source with few votes are reported with their vote count, or not at all.

### 8. People are entities, not strings

```
person(id PK, tmdb_id, imdb_id, kp_staff_id, name_en, name_ru, popularity, profile_path)
title_credit(title_id, person_id, department, character_ru, character_en, order, episode_count)
```

- **The RU↔EN mapping is built by joining on ids, never by matching names.** TMDB localizes `name`
  by `language` while keeping `id` stable, so two passes (`en-US`, `ru-RU`) joined on `id` yield
  exact pairs — verified. Kinopoisk `/staff` gives `nameRu` + `nameEn` on one row, the second exact
  pair. (`also_known_as` does **not** carry the Cyrillic form — an earlier assumption, disproved.)
- **Character names are TMDB's blind spot** — they stay English under `ru-RU`. Russian character
  names come from Kinopoisk, which is much of why that source is kept.
- Transliteration is a last resort, never overwrites a known pair, recorded as low confidence.
- Matching people by normalized display name is a **temporary hack wherever it survives** — Cyrillic
  ↔ Latin never matches under name folding, and that is the whole problem.
- Keep roughly the top 30 credits by order/popularity **plus** every director, writer and
  award-nominated person regardless of rank.

### 9. Availability is an entity — fetched late and on demand

```
availability(title_id, service, region, season, episode, kind, quality, formats, audio,
             subtitles, dubs, parental_rating, price_model, price, deeplink,
             available_from, available_until, checked_at)
```

Titles *leave*, so rows carry a validity window and accumulate into history rather than being
overwritten. But it is the most volatile data in the system and the least demanded early: resolve it
when a user actually asks "where can I watch this", cache briefly, never precompute it for the
library. Per-user answers differ, which is why paid aggregators exist — do not go shopping for one.

### 10. Studios, tags and signals are entities with a declared basis

- **Studio / network is an entity**, not a string — "a Netflix original" is a badge, an icon and a
  filter, all of which need a stable id.
- **Tags are micro-genres**, tens of thousands of them in the wild. That is a feature: it is what
  makes similarity possible later. Store them all; do not curate at ingest.
- **Signals are computed, stored, dated, and carry their basis.** A top is meaningless without saying
  what it ranks by — rating, recency, popularity, or view count. Two tops computed from different
  bases are different objects and never merge silently. "New season" needs the season's **end** date
  as much as its start.

### 11. Integrations: two kinds, one registry

Every source is an **integration** with a capability descriptor: ids it accepts, fields it supplies,
auth owner, quota, cost, freshness class. **System integrations** run on our credentials;
**user integrations** (Trakt, Plex, a personal Kinopoisk key) run on the user's, never touch our
quota, and are inspectable by that user.

- **Every fetch is written through.** A request made to render a page also persists its raw payload
  and derived rows. Burning a quota call and discarding the answer is the defect this design exists
  to kill.
- **"Did we already ask" is always answerable** — `fetch_log(provider, endpoint, key, status,
  fetched_at, ttl)`, including misses. A repeat request into the void is a bug, not a cache miss.
- **Providers cannot block each other** — one queue, one rate limiter, one backoff, one health
  record per provider. A dead provider degrades its own fields and nothing else.
- **Nothing is deleted.** Deriving is re-runnable.

### 11a. One ingest path: raw first, derive second

Sources have nothing in common in shape, and unifying at write time is what forces migrations. So we
unify at derive time:

```
raw_payload(source, endpoint, key, via, fetched_at, body)   -- append-only, any shape
      ↓  one deriver per source, re-runnable
title / person / credit / rating / image / …
```

`via` ∈ `dump | donation | fetch`. **A dump row, a donated payload and a live fetch enter through the
same function.** Schema change costs a re-derive, never a re-crawl.

### 11b. kino.pub content arrives by donation, not crawling

The client already made the call and already holds the payload; after rendering, the app posts the
non-personal slice of what it received. Zero extra kino.pub requests, zero server-side auth on the
hot path, and coverage that follows what people actually open.

- **Fire-and-forget** — never on the render path, never awaited, silent on failure.
- **Whitelist, never blacklist.** Only named fields are sent, so a field kino.pub adds later cannot
  leak by default. Watch progress, bookmarks, view marks, subscriptions and personal ratings are
  never sent, and the server has nowhere to put them.
- **Counters are the freshness signal** — vote counts and likes travelling with the donation say
  whether anything moved, which schedules a re-check without polling.
- **Two coverage classes, and donation delivers only one.** *Depth* (full documents for titles
  someone opened) arrives free. *Breadth* — a thin index over the entire library: id, title, original
  title, year, kind, external ids — does not, and intersection ("show me what of this 300-title list
  is watchable here") needs completeness, not popularity. Breadth is cheap and is held from the
  start; a system account maintains it at a polite rate.
- We do **not** relay the user's own kino.pub calls through our server: it would put us in the path
  of every screen, add latency next to playback, make the app depend on our uptime, and hand us
  personal data we refuse to hold — while buying nothing donation does not already give.

### 12. The user layer is ours; playback stays kino.pub's

We own cheap metadata, enrichment, trailers, recommendations and the home-screen collections. We do
**not** store watch progress or personal lists — kino.pub already holds them correctly and a second
copy only creates reconciliation. The only per-user state we keep is what a feature cannot work
without and kino.pub has nowhere to put: preferences shaping *our* surfaces, and notification
subscriptions (a device token plus watched title ids). Each justified individually.

### 13. Never blocking, never chatty

The client paints the kino.pub payload first; enrichment arrives later and only ever adds. One
document per title per call — no GraphQL, `?include=` trims, default is everything. The API answers
with what is warm and refreshes the rest in the background. One in-flight request per key, both
sides.

## Rules for code written today

- **New providers land server-side, not in the app.** The app gets one more field, not one more
  network client. The in-app provider slot is for **user-keyed** sources only (Kinopoisk with the
  user's own key), because those calls must not run through our infrastructure.
- **The app models our merged document, never a provider's response shape.** A DTO named after a
  vendor does not belong in app code once that provider is behind our API.
- **Never key an app-side cache on a provider id.**
- **Never build UI that needs a second lookup to decide whether to render.** Sections hide on an
  empty field, not on a pending request.
- Any name-based matching added now carries a comment marking it as pre-`person`-table.

## Platform notes

- Matching is free via `MediaItem.imdb` / `MediaItem.kinopoisk` — TMDB `/find`, Trakt, IntroDB and
  Kinopoisk Unofficial all accept these. Prefer id match over title fuzzy match.
- TMDB via our Cloudflare worker: cast photos, character names, title logos, air dates, tagline,
  budget/revenue, companies, trailers. `append_to_response` keeps enrichment to one round trip.
- Kinopoisk Unofficial (per-user key) + keyless `kpapp.link` proxy: awards, facts, stills, reviews,
  RU character names. Free tier ~500 req/day; the proxy can die, so sections hide when empty.
- Trakt can supply `next_episode` progress — useful later, but needs a scrobbling commitment.
- **kino.pub's own API docs (kinoapi.com) are incomplete.** Pin real JSON with decode tests when
  shapes matter.

## Known defects in today's implementation

Recorded so they are not mistaken for decisions:

1. **No IMDb id → no TMDB at all.** `TMDBSource` returns early and `MediaItemModel` does not even
   call the service. There is no `/search` fallback; when one is added it must search by **original
   title + year** — a RU-title query returns nothing for obscure foreign films.
2. **Cross-alphabet cast matching is impossible.** `TitleMetadata.normalize` folds diacritics only,
   so «Реми Безансон» never matches "Rémi Bezançon" and every photo, character and person id stays
   nil. (The person page draws the right circle today only because the photo path resolves off the
   kino.pub name we already hold — a workaround for this, not a fix.)
3. **Merge order is non-deterministic** — a task group consumed in completion order with gap-fill
   merge means the faster source wins that run. No provenance recorded.
4. **Kinopoisk uses 5 endpoints** (`films`, `staff`, `awards`, `images?type=STILL`, `facts`) while
   our own offline schema already models `box_office`, `videos`, `seasons`, `similars`, `reviews`
   and `/staff/{id}`. The app is behind our own schema.
5. **The kino.pub snapshot is thin** — 53 485 items in 24 flat columns, no genres, tags, collections,
   seasons/episodes, dubs or cast; documentaries and concerts skipped. A title index, not a catalogue.
6. **No ratings model** on `TitleMetadata` at all, per-title or per-episode.
7. **Cache is per-device and volatile** — `Caches/KinoPubMetadata` is purged on tvOS whenever the app
   is not running, so every cold launch re-spends third-party quota on the same titles.
8. **The worker is a dumb forwarder** — no identity storage, no merge, no image route.

The minimum useful next step is therefore not a crawler. It is a provider registry with real quota
isolation, a sync layer that writes through, and a documented model of every source.
