# Plan: metadata service — registry, sync, and where the code lives

> **Archived 2026-08-13.** Survived: the registry / write-through sync / document-every-source
> shape, now in the `metadata-service` skill along with the known defects. Nothing here was
> built — `workers/tmdb-proxy` is still a transparent forwarder.


> **Dated implementation history — not living authority.** The durable rules are
> [policies/metadata-architecture](../../../.claude/skills/metadata-service/SKILL.md). Open feature work:
> [06-discovery-and-enrichment](../../../ROADMAP.md). Provider sheets:
> [providers/](../../providers/README.md).

Date: 2026-08-11. Status: not started. `workers/tmdb-proxy` is the only deployed piece and is a
transparent forwarder.

## The actual problem, stated small

Not "build an encyclopedia". The encyclopedia is the end of the roadmap; the UI is the bottleneck
today. What is broken *now*:

- **Requests go into the void.** Every enrichment call renders once and is discarded into a
  per-device cache that tvOS purges. The same quota is spent again on the next cold launch.
- **There is no sync.** The server and this repo are unrelated; what exists server-side is
  half-implemented, unused at full capacity, and invisible from here.
- **Existing sources are used at a fraction of their surface**, and nothing records what they *can*
  do, so the gap is invisible until someone reads the API docs again.

The minimum useful thing is therefore not a crawler. It is: **a provider registry with real quota
isolation, a sync layer that writes through, and a documented model of every source** — so that the
calls we already make stop being wasted and the library fills as a side effect of ordinary use.

## Repository and module layout

### Server: one new repo, one module per concern

Split by *what changes together*, not by taste. Separate repos only when deploy cadence genuinely
differs — for one maintainer, one repo with hard module boundaries is the cheaper version of the
same isolation.

```
kinopub-meta/
  core/          domain models, id namespaces, provenance, error taxonomy
  store/         Postgres schema, migrations, raw-payload store
  registry/      capability descriptors, credentials, rate limits, health
  providers/
    tmdb/ kinopoisk/ apple/ tvoe/ imdb-datasets/ trakt/ omdb/ tvdb/ …
        client · DTOs · mapper · quota policy · fixtures · sheet.md
  sync/          job runner: queues, schedules, backoff, dedup, write-through
  merge/         precedence + provenance resolver → published document
  publish/       record → edge read model
  api/           the only surface the client sees
  admin/         per-provider health, last errors, replay a stored fetch
```

The rule that makes this pay: **a provider module owns everything about that provider and nothing
else**. Adding provider #7 is a directory plus a registry entry — no edits in `merge/`, `api/`, or
any other provider. If adding a source requires touching a second provider's code, the boundary is
wrong.

Each provider directory carries its own `sheet.md` (the template in
[providers/](../../providers/README.md)) next to its code, so the model documentation cannot drift away
from the client that uses it.

### Client: do not restructure it now

Plozz's 46-module split is the right instinct for *its* problem — it has many interchangeable media
backends, so `MediaProvider` + one module per service is load-bearing. Ours is the mirror image:
**one** media backend (kino.pub) and many metadata providers, and the policy already says metadata
providers live server-side. Copying that layout into this app would drag exactly the code we are
moving out back into the client.

What is worth borrowing from it is narrower and free:

- a `sheet.md`/`README.md` per module documenting responsibility, public surface, and invariants —
  we already do this for docs, not for packages;
- one service module per external service **on the server**, which is the layout above.

Our five packages (`KinoPubBackend`, `KinoPubKit`, `KinoPubUI`, `KinoPubLogging`, `KinoPubMetadata`)
are proportionate. Splitting `Views/` into `Feature*` modules is a real option later, when build
times or agents cross-cutting one another actually hurt — not before. The one client change this
plan implies: `KinoPubMetadata` shrinks to a client of our API plus user-keyed sources.

## Hosting

Three roles, and the question is only which product fills each:

| Role | Reads it | Choice |
| --- | --- | --- |
| **System of record** — raw payloads, entity graph, jobs, derived tables | Batch jobs and the publish step. **Never the client** | **Supabase** (managed Postgres), or self-hosted Postgres on the VPS |
| **Batch runner** — crawler, importers, derivers, image colour extraction | — | **VPS**, where `tools/*` already lives |
| **Published read model** — compact documents, identity map, image resolution, prebuilt rows | The TV app, constantly | **Cloudflare Workers + D1/KV** |

**Supabase is a reasonable record tier and my earlier objection was aimed at the wrong tier.**
Free-instance pausing only matters for something that must answer a user instantly; the record is
read by batch jobs and by the publish step, so a pause costs a wake-up, and it restores from backup.
Managed Postgres also removes exactly the babysitting that made the VPS unattractive — no OS
patching, no backup cron of our own, an SQL editor for poking at the graph.

Film-Glance runs precisely this split — Supabase as primary DB, a Hostinger VPS for the crawler,
importers and forum, Vercel for the app, Cloudflare on DNS — which is the same shape arrived at
independently. The difference is the last row: their client is a website behind a CDN, ours is a TV
app hammering artwork, so we keep an edge read model where they do not need one.

Also worth stealing from them: a **30-day normalized cache with stale-while-revalidate plus a daily
cron that refreshes only the N most-popular expired entries**. That is a concrete, cheap refresh
policy for ratings, and it beats "re-crawl everything on a schedule".

Backups: Supabase's own for the record (or `pg_dump` if self-hosted), `wrangler d1 export` for the
published model. Their bot-deploys-to-git pattern is worth copying for the *build*, not the database.

Still rejected: everything-on-edge (a crawl's write volume does not fit free daily ceilings),
everything-on-the-VPS (no free edge cache for the path the TV app hits constantly), Firebase (wrong
shape for a relational identity/person graph), Redis (no hot ephemeral state to hold).

## Secrets and endpoints

Verified 2026-08-11 against the live deployment:

- `kinopub-tmdb-proxy.traneblow1nd.workers.dev` runs **exactly** `workers/tmdb-proxy/src/index.js`
  (the deployed bundle is that file, esbuild-wrapped). It is not empty and not scaffolding.
- `TMDB_READ_TOKEN` **is** configured — `/3/find/tt0903747` returns live TMDB data, not the
  `misconfigured` 500. `/` returns the 404 hint by design; the image branch forwards correctly.
- So there is nothing to recover or re-create here. What it lacks is a *service*: no storage, no
  identity map, no image route by kino.pub id.

What must change about how secrets travel:

- **The API token is already handled correctly** — a `wrangler secret`, never in the repo.
- **The worker URL is not.** `KinoPubAppleClient/Info.plist` carries the personal endpoint in a
  tracked file. Move it to a gitignored `Config/Secrets.xcconfig` referenced from `Info.plist` via
  `$(TMDB_PROXY_BASE_URL)`, with a committed `Config/Secrets.xcconfig.template` holding an empty or
  example value. The app already tolerates the key being absent (`isConfigured` gates the source),
  so a fresh clone degrades to "no external metadata" instead of failing to build.
- The kino.pub `ClientID`/`ClientSecret` in the same file are the public `xbmc` pair every kino.pub
  client ships — not personal credentials, and not what this is about.
- **Worker code is committed and deployed from the repo**, never edited in the Cloudflare dashboard.
  A dashboard edit is invisible here and is lost on the next `wrangler deploy`.

## Stages

### 0. Import what already exists

Before any fetching. The kino.pub sweep, the tvoe pull, and the Kinopoisk pull were already paid for
in quota and time; the first ingest reads those dumps and live fetching starts from what is missing.
Awaiting the dump link from the user. Schema for the record is designed to receive them, not the
other way round.

### 1. Registry + sync + write-through — the minimum useful thing

- Capability descriptor per provider: ids accepted, fields supplied, auth owner (system or user),
  quota, cost, freshness class.
- One queue, one rate limiter, one backoff, one health record **per provider** — so a throttled
  source degrades only its own fields.
- `fetch_log(provider, endpoint, key, status, fetched_at, ttl)` including misses. "Did we already
  ask" becomes answerable, which is the single complaint this stage exists to fix.
- Write-through: any fetch triggered by rendering also persists raw + derived. Ordinary use fills
  the library.
- `admin/`: per-provider health, last error, remaining quota, replay a stored fetch.

### 2. Record + identity

Postgres schema (`title`, `title_external_id`, `raw_payload`, `job_run`), seeded from what already
exists on disk rather than re-fetched: `tools/kinopub-snapshot` (53 485 titles),
`tools/kinopoisk-metadata`, `tools/tvoe_data` (4 348). Resolution ladder incl. `/search` by original
title + year.

### 3. Published document + `/v1/title/{id}`

Generator record → compact document with per-field provenance → D1/KV. `by/{namespace}/{value}`
entry points. Client gets one source that hits our API and takes precedence when configured; the
user-keyed Kinopoisk source stays client-side.

### 3a. Donation endpoint (MVP shape of the detail screen)

`POST /v1/donate/kinopub/{id}` — the app posts the whitelisted slice of the item payload it just
rendered. Fire-and-forget, silent on failure.

The detail screen then runs two requests in parallel: kino.pub item (personal state, streams,
playback) and `/v1/title/by/kinopub/{id}` (everything shown *about* the title). Enrichment paints
from ours, playback from theirs — which is what the app already does with two client-side sources,
so this is a swap rather than new architecture.

Identity hints travel on the first call and double as the change signal: original title, year, kind,
kino.pub id, Kinopoisk rating + vote count, IMDb rating + vote count, kino.pub likes. Vote counts
moving is what schedules a re-check; nothing polls.

A separate system account backfills titles nobody opened, rate-limited, as a background worker.

### 4. Images

`/img/{kind}/{size}/{ns}/{id}` is the path the client always uses — it resolves the winning source
and answers with the image or a redirect, falling back down the chain to kino.pub's own artwork so
there is never a hole. The provider-canonical URL also travels in the document for callers that want
the origin. Snapshot only URLs that are unstable by construction.

**Average colours are computed at ingest, on the VPS, not at request time.** Two values per image —
top band and bottom band, not one average — because that is what a gradient scrim over a poster
actually needs. Pillow downscales to a few pixels and averages two strips; the pair is stored as hex
on the image row and travels in the document. Workers cannot decode JPEG without dragging in a
decoder, and a TV client must never compute this on device.

### 5. People and credits

`person` / `title_credit`; RU↔EN pairs from a two-language TMDB pass joined on person `id`, plus
Kinopoisk `/staff` (`nameRu` + `nameEn` on one row) and its Russian character names;
transliteration as low-confidence fallback; ~30 credits kept plus directors, writers, nominees.
Unblocks person pages, award attribution, and cross-alphabet matching for real.

### 6. Ratings, tags, studios, signals

Ratings per title **and per episode**, every source with its vote count, never pre-averaged; IMDb's
dataset dump for per-episode IMDb ratings. Tags stored wholesale. Studio/network as an entity. Tops
and badges as dated rows carrying their basis.

### 7. Catalogue depth and refresh

Collections, similars, awards, dubs, seasons/episodes, upcoming, and the documentaries/concerts the
first sweep skipped. Refresh cadence per data class and per provider mission — **not** one global
crawl queue. tvoe in particular is a small curated library: poll for what is new, and treat anything
present there as certainly present for us.

### 8. Personal layer and notifications

Likes on people and studios, muted genres/sections, hide-watched, personal stats. Push when an
episode lands — the one feature needing server-side per-user state (device token + subscription
list), deliberately bounded.

### 9. Availability, on demand

Only when a user asks where to watch. Shape and reasoning in the policy. Not precomputed, not for
the library.

### 10. User integrations and recommendations, then wrapping kino.pub's lists

Trakt, Plex, Simkl. Recommendations become honest once a source exists. Finally the client talks to
one API and kino.pub keeps streaming and account state.

## Borrow rather than write

- **agregarr** already implements clients and models for roughly six services beyond TMDB (MDBList
  is its own thing, not a TMDB wrapper). Lift the models and clients, then extend — do not re-derive
  them from vendor docs. Its OpenAPI file is also the best available reference for what a mature
  aggregator's surface looks like. It keys everything by `tmdbId`; we deliberately do not.
- **Film-Glance** normalizes nine rating platforms to one scale and ships awards and tops. Its
  README's integration post-mortem — which APIs were easy, which are flaky — is the cheapest
  available evidence for choosing rating sources. Read it before picking.
- **Subler** has working Apple `uts-api`, iTunes Store, TheTVDB, and TMDB clients in Swift.
- **shinkro / community-mapping** treat cross-source id mapping as curated data rather than
  heuristics — the correct answer to our hardest problem.

## Open questions

- **tvoe cadence**: poll interval for "what is new" on a ~4 000-title curated library, and whether
  Apple can supply the same Russian-language material well enough to make it redundant.
- **kino.pub image sizing**: enumerate the size segments their CDN accepts — it may remove a hop.
- **Availability aggregators**: shortlist pending from the user; not to be researched independently.
