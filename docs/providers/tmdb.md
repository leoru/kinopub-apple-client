# TMDB

Everything below marked **verified** was probed live through our worker proxy on 2026-08-11, not
copied from the docs. Rule zero applies: this sheet lists what TMDB offers, including what we do not
take.

**Auth:** two schemes. v3 API key as a query parameter, or the **v4 Read Access Token as
`Authorization: Bearer …`** — the token works on v3 endpoints too, which is what we use. The token
never reaches the client; the worker holds it as a `wrangler secret`.
**Quota:** no documented hard per-window limit today (the old 40 req/10 s cap was retired); TMDB
throttles abusive patterns instead. Treat as generous, not unlimited.
**Coverage:** the universal spine — strong worldwide, weakest on CIS-only obscurities. Localized
into Russian well for anything with an audience.
**Ids accepted:** its own, plus `/find` by `imdb_id`, `tvdb_id`, `wikidata_id`, and the social ids.
**Integration kind:** system (our token, via worker).
**Import capabilities:** no bulk dump. Daily **id-export** files exist (one line per entity) — the
only bulk-ish surface; everything else is per-entity.
**Images:** paths are stable, sizes are enumerated by `/configuration`. Link, never snapshot.

## The one that matters: `append_to_response`

Comma-separated sub-requests folded into a single HTTP call, each appearing as a new top-level key.

```
/3/movie/11?append_to_response=videos,images,credits,external_ids,keywords,release_dates
```

- **Verified supported on:** `movie`, `tv`, `tv/{id}/season/{n}`, `tv/{id}/season/{n}/episode/{n}`,
  `person`.
- **Verified hard limit: 20 sub-requests.** Asking for 22 returns
  `{"success":false,"status_message":"Too many append to response objects: The maximum number of
  remote calls is 20."}` — so batching is generous but bounded, and the cap belongs in the client.
- Sub-request parameters ride at the top level (`include_image_language`, `language`) and apply to
  the appended objects.

Verified appendable keys per namespace:

| Namespace | Appendable |
| --- | --- |
| `movie` | credits, images, videos, external_ids, keywords, release_dates, similar, recommendations, reviews, lists, translations, alternative_titles, changes, `watch/providers`, account_states |
| `tv` | aggregate_credits, credits, images, videos, external_ids, content_ratings, keywords, similar, recommendations, reviews, translations, alternative_titles, episode_groups, screened_theatrically, changes, `watch/providers` |
| `tv/season` | credits, **aggregate_credits**, images, videos, external_ids, translations |
| `tv/episode` | credits, images, videos, external_ids, translations (plus `guest_stars` and `crew` natively) |
| `person` | combined_credits, movie_credits, tv_credits, external_ids, images, tagged_images, translations, changes |

We currently send 6–7 of the 20 available and never touch the season/episode/person variants.

## Localization — how the Russian-name problem is actually solved

**Verified, and it corrects an earlier assumption in our policy.**

- `also_known_as` does **not** carry the Cyrillic form. Brad Pitt returns
  `["William Bradley Pitt"]` under both `en-US` and `ru-RU`.
- What *is* localized is **`name` itself**, and the **`id` is stable across locales**:

  | `language` | `credits.cast[0]` |
  | --- | --- |
  | `en-US` | `id=2  Mark Hamill  character="Luke Skywalker"` |
  | `ru-RU` | `id=2  Марк Хэмилл  character="Luke Skywalker"` |

- Therefore: **fetch twice, join on `id`.** Two passes of the same endpoint in two languages produce
  exact RU↔EN pairs with no name matching, no diacritic folding, and no transliteration. The id is
  the join key; names never are.
- **Character names are not localized** — they stay English in `ru-RU`. Russian character names come
  from Kinopoisk `/staff`, which is the actual reason that source earns its place.
- When TMDB simply has no Russian record, `name` stays Latin (verified: Rémi Bezançon, id 71506,
  identical under both locales, `also_known_as: []`, translations only `fr`/`en`). That is the
  original failing case, and it confirms no TMDB-only strategy can fix it — those need Kinopoisk or
  transliteration, flagged low-confidence.

## Models — field inventory

Shapes below are dumped from live responses, not from docs. `✅` = we store it today, `—` = it
exists and we throw it away. Rule zero says store everything; this is the list of what "everything"
actually is.

### Movie — 33 top-level fields (we map ~18)

| Field | Shape | Us |
| --- | --- | --- |
| id, imdb_id, title, original_title, original_language, overview, tagline, homepage, status, runtime, budget, revenue, release_date | scalars | ✅ |
| poster_path, backdrop_path | str | ✅ |
| genres | `[{id,name}]` | — kino.pub's genres used instead; TMDB ids are the join key to `/discover` |
| **popularity, vote_average, vote_count** | float/int | **— the ratings we do not capture** |
| **belongs_to_collection** | `{id,name,poster_path,backdrop_path}` | **— franchise grouping, free** |
| production_companies, production_countries, spoken_languages, origin_country | arrays | ✅ companies only |
| adult, video, **softcore** | bool | — (`softcore` undocumented) |
| credits | `cast[{adult,cast_id,character,credit_id,gender,id,known_for_department,name,order,original_name,popularity,profile_path}]`, `crew[…,department,job]` | ✅ partially — **gender, popularity, original_name, credit_id dropped** |
| images | `{posters,logos,backdrops}`, each `{file_path,aspect_ratio,width,height,iso_639_1,iso_3166_1,vote_average,vote_count}` | ✅ one winner per kind — **all alternates, their dimensions and community votes dropped** |
| videos | `[{key,site,type,name,official,published_at,size,iso_639_1,iso_3166_1}]` | ✅ |
| external_ids | `{imdb_id,wikidata_id,facebook_id,instagram_id,twitter_id}` | — **wikidata_id is the bridge to everything else** |
| keywords | `[{id,name}]` | ✅ names only — **ids dropped, and ids are what similarity needs** |
| release_dates | `[{iso_3166_1,release_dates:[{certification,descriptors,iso_639_1,note,release_date,type}]}]` | ✅ certification only — **per-country premiere dates and `type` (theatrical/digital/physical) dropped** |
| **translations** | `[{iso_639_1,iso_3166_1,name,english_name,data:{title,overview,tagline,homepage,runtime}}]` | **— every localized title and synopsis, in one call** |
| **alternative_titles** | `[{iso_3166_1,title,type}]` | **— the search-matching aid we lack** |
| **watch/providers** | 85 countries, each `{link,buy/rent/flatrate:[{provider_id,provider_name,logo_path,display_priority}]}` | **— availability, already free, already there** |
| **reviews** | `[{author,author_details,content,created_at,updated_at,url}]` | **— reviews UI is an open checklist item** |
| **similar, recommendations** | paginated title lists | **— TMDB's own recommendations, unused** |
| lists | paginated | — low value |

### TV — 45 top-level fields

Everything above, plus: `created_by[{id,name,credit_id,gender,profile_path}]`, `networks`,
`seasons[{id,season_number,name,overview,air_date,episode_count,poster_path,vote_average}]`,
`next_episode_to_air`/`last_episode_to_air` (full episode objects incl. `vote_average`,
`episode_type`, `runtime`, `still_path`), `in_production`, `type`, `languages`, `episode_run_time`.

- `external_ids` here also carries **`tvdb_id`**, `tvrage_id`, `freebase_*` — the TVDB bridge.
- `content_ratings` → `[{iso_3166_1,rating,descriptors}]` — ✅ rating only, **descriptors dropped**.
- **`episode_groups`** → `[{id,name,type,description,group_count,episode_count,network}]` — alternate
  orderings (absolute, DVD, story arc). **Anime and long-running shows are unwatchable without this.**
- **`aggregate_credits.cast[]`** → `{id,name,original_name,gender,popularity,known_for_department,
  order,profile_path,total_episode_count,roles:[{character,credit_id,episode_count}]}` — ✅ we take
  name/character/photo/episode_count and **drop `roles[]` (multiple characters per actor),
  `total_episode_count`, `popularity`, `order`**. Popularity and order are exactly the ranking the
  policy's "top 30 plus directors" rule needs.
- `screened_theatrically`, `alternative_titles`, `translations` — all unused.

### Season — 16 fields

`credits` **and** `aggregate_credits`, `images.posters`, `videos`, `translations`,
`external_ids{tvdb_id,…}`, `networks`, `vote_average`, and `episodes[]` inlined with full episode
objects. **We call `/season/{n}` without a single append.**

### Episode — 19 fields

`vote_average`, `vote_count`, `episode_type` (standard/finale/mid_season), `production_code`,
`runtime`, `still_path`, `crew[]`, **`guest_stars[{id,name,character,order,popularity,profile_path}]`**,
plus appendable `images.stills`, `videos`, `translations`, `external_ids{imdb_id,tvdb_id}`.

**Per-episode ratings and guest stars are sitting right here and we take neither.**

### Person — 19 fields

`biography`, `birthday`, `deathday`, `place_of_birth`, `gender`, `known_for_department`,
`popularity`, `profile_path`, `also_known_as[]`, `imdb_id`, plus appendable:

- **`combined_credits.cast[]`** → full filmography with `character`, `media_type`, `order`,
  `release_date`, `vote_average`, artwork — **a person page for one request**.
- **`images.profiles[]`** — every portrait with dimensions and votes, not just the one.
- **`external_ids`** → `{imdb_id,wikidata_id,tiktok_id,youtube_id,instagram_id,facebook_id,twitter_id,…}`.
- `translations`, `tagged_images`.

We call `/person/{id}` bare and map five fields.

### Endpoints we have never touched

`/search/{movie,tv,person,multi,collection,company,keyword}` · `/discover/{movie,tv}` (the whole
filter engine: by genre, keyword, year, rating floor, vote-count floor, provider, region, cast,
crew, runtime, sort order — this is how catalogue browsing and "more like this" get built) ·
`/trending/{all,movie,tv,person}/{day,week}` · `/movie/{popular,top_rated,now_playing,upcoming}` ·
`/tv/{popular,top_rated,on_the_air,airing_today}` · `/collection/{id}` · `/company/{id}` ·
`/network/{id}` · `/keyword/{id}/movies` · `/genre/{movie,tv}/list` · `/certification/{movie,tv}/list` ·
`/credit/{credit_id}` · `/watch/providers/{movie,tv,regions}` · `/{movie,tv,person}/changes` (the
delta feed — the correct way to schedule refreshes) · daily **id-export dumps**.

## Recommendation

Ordered by value per unit of work. All of the first group are **zero extra requests** — they are
append slots we already pay for and leave empty.

**1. Fill the append budget (6 → ~15 of 20 slots).** Add to the title call:
`translations, alternative_titles, watch/providers, reviews, recommendations, similar` for movies;
the same plus `episode_groups` for TV. This alone unlocks the reviews section, availability,
localized titles, TMDB-native recommendations, and franchise grouping — with no new round trips.

**2. Stop discarding fields we already receive.** `vote_average`/`vote_count` at title, season and
episode level; `popularity` and `order` on credits (the ranking the top-30 rule needs); `roles[]`
for actors with several characters; `belongs_to_collection`; `wikidata_id` and `tvdb_id`; keyword
**ids**; image dimensions and community votes so a "best artwork" choice is defensible instead of
first-wins.

**3. Append at season, episode, and person level** — currently zero appends on all three. Season
`aggregate_credits` + `images` + `external_ids`; episode `images.stills` + `guest_stars` (already
free, no append needed); person `combined_credits` + `images` + `external_ids` gives a full person
page in one request.

**4. `/search` fallback.** By original title + year when the IMDb id is missing — the single defect
that makes titles get no metadata at all today.

**5. `/discover` + `/trending` + `/changes`.** `discover` is the engine behind catalogue browsing,
editorial rows, and honest "more like this"; `changes` is the correct refresh scheduler and replaces
polling. These are new integrations rather than free extras, so they follow the first four.

**6. Second-language pass.** One extra request per title, gives Russian person names and localized
synopses by id-join. Worth it once people are entities.

## Other verified facts

- **`/configuration`** — `secure_base_url: https://image.tmdb.org/t/p/`, sizes:
  `poster` w92·w154·w185·w342·w500·w780·original · `backdrop` w300·w780·w1280·original ·
  `logo` w45·w92·w154·w185·w300·w500·original · `profile` w45·w185·h632·original ·
  `still` w92·w185·w300·original. This is the authoritative mapping for our own size tokens.
- **Per-episode ratings exist**: an episode payload carries `vote_average` and `vote_count`. TMDB is
  therefore a per-episode ratings source, not only IMDb datasets.
- **`/find` verified** for `imdb_id` (200 with results) and `tvdb_id` (200).
- **Undocumented field observed**: `softcore` (boolean) on both movie and tv payloads. Store it;
  decide later.

## v4

A separate namespace, mostly **account, list management, and auth** (user-scoped lists with
pagination and filtering, which v3's list API does poorly). The **data** endpoints we care about
remain v3, and the v4 token authenticates both. An OpenAPI/spec surface is published — locate it and
generate the model section from it rather than hand-writing fields.

Relevant to us only when user integrations arrive (a user's own TMDB lists). Not needed for
enrichment.

## Verdict

TMDB wins: identity spine, cast/crew lists with order and episode counts, title logos with language
scoring, backdrops, posters, keywords, trailers, companies/networks, air dates, per-episode
ratings, and — through the two-language pass — Russian person names.

TMDB does not win: Russian character names, awards, facts, stills galleries, CIS-only obscurities.

Immediate gaps in our integration: no `/search` fallback when IMDb id is absent, no season/episode/
person appends, no second-language pass, no per-episode ratings captured, 6 of 20 append slots used.
