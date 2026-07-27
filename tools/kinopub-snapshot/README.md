# kino.pub library snapshot

Standalone script, unrelated to the Apple client's build — pulls a trimmed,
parent-level (no episodes) snapshot of the kino.pub catalog into a local SQLite
file, for later offline matching against external metadata (awards, etc.). Not
part of the Xcode project; nothing here ships in the app.

## Why

`/v1/items?type=X&sort=-created&page=N` (already used by the app's Library tab)
returns everything needed per listing page — no need to walk ids one by one, and
no need to scrape kino.watch. kino.pub's id space runs past 125k but only ~53.5k
items are actually populated (639+158+104+57+92+9+15 pages across the 7 types as
of 2026-07), which is exactly why paginating beats enumerating ids.

## Usage

```
python3 snapshot.py                        # full sweep, all 7 types
python3 snapshot.py --types movie,serial   # just these
python3 snapshot.py --resume               # continue from last saved page per type
python3 snapshot.py --token <access_token> # skip Keychain, use a token from a live app session
```

Output: `data/snapshot.db` (gitignored — personal data, not committed).

### Auth

Tries, in order: a cached token (`data/token_cache.json`), then the macOS
Keychain (`security find-generic-password -s com.kunst.kinopub`, the service the
Apple client itself writes to after device-code auth — needs you to approve the
system prompt). If neither works, pass `--token` with an access token copied out
of a live app session's `CURLLoggingPlugin` console output. Token refresh via
`/oauth2/token` only works when a `refresh_token` is on hand (the Keychain path
has one; a manually pasted `--token` doesn't, so it's good for one run of
whatever length the token's `expires_in` allows — 24h as observed).

Every run always restarts each type at page 1 (sort is `-created`, newest
first): cheap re-fetches of the first few pages catch anything added mid-run,
and `INSERT ... ON CONFLICT` makes re-syncing a no-op for everything unchanged.
`--resume` exists only to pick a *crashed* run back up without redoing pages it
already saved — not for routine re-syncs.

## Schema

Single `items` table, one row per kino.pub id (movies, series, docuseries,
docu-movies, concerts, tvshows, 3D — whatever `type` the API reports, which
already distinguishes series-shaped content from movies without guessing):

`id, type, subtype, title, title_ru, title_original, year, countries (JSON
array), imdb_id, imdb_rating, imdb_votes, kinopoisk_id, kinopoisk_rating,
kinopoisk_votes, kinopub_rating_votes, kinopub_rating_percentage, views,
poster_thumb, poster_wide, finished, created_at, updated_at, first_synced_at,
last_synced_at`

Indexed on `imdb_id`, `kinopoisk_id`, `type`, `created_at` — join external
metadata (awards, etc.) against `items.imdb_id` / `items.kinopoisk_id` in a
separate table keyed by the same ids; no need to touch this one.

## Not covered yet

Episode-level data (seasons/episodes aren't in the listing payload — only in
`/v1/items/{id}` per-item details, which this script doesn't call to keep the
sweep to ~1,100 requests instead of ~53,500).
