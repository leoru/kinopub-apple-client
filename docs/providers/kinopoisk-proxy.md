# Kinopoisk proxy (`kpapp.link/kpapi`)

**Auth:** none. No key, no header, no cookie — the same path the
[community fork](../community-fork.md) uses.
**Quota:** none documented, none observed. It is somebody else's proxy in front of the Kinopoisk
Unofficial API, so treat availability as best-effort and every field as optional: the source is one
person's server, not a product with an SLA.
**Coverage:** whatever Kinopoisk itself has — strong on Russian releases and on anything with a
Russian theatrical or streaming history, thin on the long tail of foreign TV. Reviews are the
weakest of the four: a well-known title has dozens, a typical one has none.
**Ids accepted:** Kinopoisk film id only (`mediaItem.kinopoisk`). No search, no title matching, no
imdb/tmdb lookup — a title without a Kinopoisk id gets nothing from this source.
**Integration kind:** system. Always configured (`isConfigured` is `true` unconditionally), because
there is no credential to configure.
**Import capabilities:** per-title fetch only. No dumps, no list endpoints, no changes feed.
**Images:** `st.kp.yandex.net` (headshots) and `avatars.mds.yandex.net` (stills). The avatars URLs
carry a content hash segment, so they are stable per image but **not** reconstructible — store the
URL, do not build it.

**Where it is used:** `KinopoiskProxySource` (`Packages/KinoPubMetadata/…/Kinopoisk/`). The keyed
`KinopoiskSource` covers the same ground when the user has their own API key; this fills the gaps
and is the only path most users ever hit.

## Endpoints

All four are `GET https://kpapp.link/kpapi/films/<kinopoiskId>/<resource>`, all captured live
against `12450` (Чёрный нарцисс) on 2026-08-17.

| Resource | Envelope | Notes |
| --- | --- | --- |
| `facts` | `{ total, items[] }` | Trivia and goofs |
| `reviews` | `{ total, totalPages, totalPositiveReviews, totalNegativeReviews, totalNeutralReviews, items[] }` | **Paged. `items` is page 1 only** |
| `staff` | bare array | Full crew, not just cast |
| `images` | `{ total, totalPages, items[] }` | Stills |

404 is a real answer (no such film id) and is cached as a negative entry for 30 days, same as a
success. Anything else — timeout, 5xx, malformed JSON — is *not* cached, so it retries next launch.

### `facts`

| Field | Type | Notes |
| --- | --- | --- |
| `text` | String | Contains `<a href=…>` markup and named/numeric HTML entities (`&laquo;`) |
| `type` | String | `FACT` or `BLOOPER` (киноляп). **We do not distinguish them yet** — both render as a fact |
| `spoiler` | Bool | Drives the tap-to-reveal row |

### `reviews`

Page-level:

| Field | Type | Notes |
| --- | --- | --- |
| `total` | Int | Reviews on the title, **not** `items.count` |
| `totalPages` | Int | Observed `1` on a title with 11 reviews, so the page size is ≥ 11 and unknown |
| `totalPositiveReviews` | Int | |
| `totalNegativeReviews` | Int | |
| `totalNeutralReviews` | Int | The three sum to `total` in every capture so far |

Item-level:

| Field | Type | Notes |
| --- | --- | --- |
| `kinopoiskId` | Int | The **review's** id, not the film's. Carried as `Review.sourceId`, unused: Kinopoisk's own review URL is `/user/<userId>/comment/<commentId>/` and the user id never arrives, so the expanded card links to the title's review list instead of the review |
| `type` | String | `POSITIVE` / `NEGATIVE` / `NEUTRAL` |
| `date` | String | `2022-02-18T21:51:09` — **no zone offset**, so there is no instant to recover. Read in the current calendar's zone so the printed day matches Kinopoisk's page |
| `positiveRating` | Int | "Useful" votes on the review. **Not** its sentiment: a NEGATIVE review can be widely agreed with (one capture: 23 useful / 79 not) |
| `negativeRating` | Int | |
| `author` | String | Display name, sometimes an initial (`Арсений П.`) |
| `title` | String? | **Null about half the time.** A review with no headline is normal, not a defect |
| `description` | String | The body. HTML: `<br />\r\n<br />` between paragraphs, entities throughout. Thousands of characters — 4 000+ is ordinary |

### `staff`

A bare array, no envelope — the one endpoint of the four that is not `{ items: [] }`.

| Field | Type | Notes |
| --- | --- | --- |
| `staffId` | Int | Kinopoisk person id |
| `nameRu` / `nameEn` | String? | Either can be null; we prefer `nameRu` |
| `description` | String? | For actors, the **character**. Null for crew |
| `posterUrl` | String? | Headshot. Placeholder URLs exist and are filtered by `nonPlaceholderImageURL` |
| `professionText` | String | Russian plural label (`Режиссеры`) — **we ignore it** and use the key |
| `professionKey` | String | `ACTOR`, `DIRECTOR`, `WRITER`, `PRODUCER`, `OPERATOR`, `COMPOSER`, `DESIGN`, `EDITOR`, `VOICE_DIRECTOR`, `TRANSLATOR`, … We map `ACTOR` only |

### `images`

| Field | Type | Notes |
| --- | --- | --- |
| `imageUrl` | String? | Full size (`…/orig`) |
| `previewUrl` | String? | `…/300x`. The two differ only in the trailing size segment, but do not synthesise one from the other — the segment vocabulary is Yandex's |

## What we take, and what we leave

| Field | Taken | Why not |
| --- | --- | --- |
| `facts.type` (`BLOOPER`) | ✗ | Goofs and trivia render identically; separating them is a product decision nobody has made |
| `reviews.kinopoiskId` | ✓ (`sourceId`) | Carried but not linkable — see the table above |
| `reviews.totalPages` | ✗ (decoded, unused) | Paging the proxy is a feature, not a mapping — see below |
| `staff` non-`ACTOR` rows | ✗ | Crew comes from kino.pub and TMDB, which carry departments |
| `staff.professionText` | ✗ | Russian-only plural label; `professionKey` is the stable one |
| everything else | ✓ | |

## Known gaps

- **Reviews are one page.** `total` regularly exceeds what `items` holds, which is why
  `ReviewsSummary.total` and the rail's card count legitimately disagree. Nothing here requests
  page 2 — the query parameter the proxy accepts for it has not been probed.
- **`BLOOPER` is thrown away.** The fact rows would read better split into Trivia and Goofs.
- **Crew is dropped entirely**, including directors this endpoint knows about and characters for
  non-acting roles.
