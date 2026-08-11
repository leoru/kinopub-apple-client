# Metadata ingest

One record, built from every local dump plus live TMDB. Python 3 stdlib only —
no `pip install`.

```bash
cd tools/metadata-ingest
make            # import dumps, then fetch TMDB for whatever is missing
make stats      # what is in there now
```

`make` is safe from any state and safe to interrupt. Re-running imports changes
nothing (every write is keyed by source ids), and a killed TMDB fetch resumes
where it stopped.

Rules this implements live in
[policies/metadata-architecture](../../docs/en/policies/metadata-architecture.md);
the TMDB field inventory is [providers/tmdb](../../docs/en/providers/tmdb.md).

## Shape

```
raw_payload        every source row, untouched, whatever its shape
      ↓            one deriver per source, re-runnable
title · person · title_credit · image · rating · video · segment ·
badge · episode · award · genre · country · synopsis
```

Sources do not share a format and are not made to. They land raw and are
unified at derive time, so a schema change costs a re-derive, never a re-crawl.
`via` on every raw row records how it arrived — `dump`, `fetch`, or `donation`.

## Sources

| Source | Input | Rows in | What only it has |
| --- | --- | --- | --- |
| kino.pub | `kinopub-snapshot/data/snapshot.db` | 53 485 | The spine. Every other source attaches to what it creates |
| Kinopoisk | `kinopoisk-metadata/data/kinopoisk.db` | 2 327 films | Awards, RU+EN name pairs on one row, 40k episode synopses, six rating scales |
| tvoe | `tvoe_data/catalog_*_detailed.json` | 4 348 | Clean Russian artwork, RU title logos, **intro/outro markers**, audio and subtitle tracks, premiere badges |
| TMDB | live, via the worker proxy | on demand | Identity spine, every artwork variant, credits, trailers, keywords, watch providers |

Import order is fixed: kino.pub first so it seeds the spine.

## How titles are matched

`common.resolve_title` is the only place this happens, and it records the method
it used on `title_external_id.method`:

1. **Any external id we already hold** — `id:imdb`, `id:kinopoisk`, `id:tvoe`.
2. **Normalized original title + year ±1** — sources disagree about release year
   by a year constantly. Recorded as `title_year:norm_original`, confidence 0.8.
3. **Normalized Russian title + year ±1**.
4. **New title.**

An ambiguous title match is *not* a match: if two rows come back, a new title is
created instead. Two films with the same original title in the same year exist,
and guessing is worse than a duplicate.

kino.pub rows never fuzzy-match each other (`allow_title_match=False`) — only
their ids join them, or remakes would collapse into one title.

Matching is deliberately **within one alphabet**. `match_key` folds case,
diacritics and punctuation, so Cyrillic and Latin normalize to different
strings by design. Pairing those is an id-join job, not a string job.

## TMDB fetch

`fetch_tmdb.py` walks titles that have an IMDb id, **most-voted first**, so an
interrupted run has still covered what people actually open.

Per title: one `/find` plus one detail request carrying **12–13 append slots of
the 20 available** — credits, images, videos, external ids, keywords, release
dates, translations, alternative titles, watch providers, recommendations,
similar, reviews, and episode groups for series. The app currently sends six.

- No token here — the worker holds it.
- `fetch_log` records answers including misses, so nothing is ever asked twice.
- 8 workers at 12 rps ≈ 5 titles/second; the whole 45k IMDb set is a couple of
  hours.
- `--language ru-RU` by default: TMDB localizes person names and synopses while
  keeping ids stable, which is what makes RU↔EN pairing an id-join.

**Cloudflare answers the default `Python-urllib` user agent with 403**, which
reads as "no match" everywhere downstream. The client sets a real one; keep it
if you copy this code.

## Files

| File | Owns |
| --- | --- |
| `schema.sql` | The record. Uniqueness is enforced by `COALESCE` indexes, never by composite primary keys containing nullable columns — a NULL never equals a NULL in SQLite, so such a key silently accepts duplicates and every re-run doubles the table |
| `common.py` | Db handle, matching keys, title/person resolution, run logging |
| `sources.py` | One importer per dump. Adding a source is a function here plus a line in `ingest.py` |
| `ingest.py` | CLI and orchestration |
| `fetch_tmdb.py` | Live TMDB fill |
| `Makefile` | The workflow |

`data/` is gitignored. `make backup` writes a gzipped SQL dump that is fine to
commit or push elsewhere.
