# Metadata ingest

One record, built from every local dump plus live TMDB. Python 3 stdlib only —
no `pip install`.

```bash
cd tools/metadata-ingest
make            # local dumps + TMDB's free daily id dumps. No API calls.
make stats      # what is in there now
make tmdb LIMIT=200      # detail fetch, opt-in, most-voted first
```

**Detail fetching is never part of `make`.** One request per title against a
personal token is not something a build step should decide to spend. `make all`
covers breadth — local dumps plus TMDB's free daily id exports — and depth is
asked for explicitly, per title, when a page actually needs it.

`make` is safe from any state and safe to interrupt. Re-running imports changes
nothing (every write is keyed by source ids), and a killed TMDB fetch resumes
where it stopped.

Rules this implements live in
[policies/metadata-architecture](../../.claude/skills/metadata-service/SKILL.md);
the TMDB field inventory is [providers/tmdb](../../docs/providers/tmdb.md).

## Shape

```
raw_payload        every source row, untouched, whatever its shape
      ↓            one deriver per source, re-runnable
facts about the work        title · person · title_credit · image · rating ·
                            trailer · badge · episode · award · genre ·
                            country · synopsis
facts about one platform's  title_copy · copy_video · copy_segment
copy of it
```

**A platform's copy is not the work.** tvoe's audio tracks, its encode's intro
offsets and its stream URLs describe tvoe's file. Merging them onto `title`
would claim kino.pub has dub tracks it does not, and that an intro ends at
second 125 of an encode nobody here will play. They hang off `title_copy`,
which is also where availability lands when it arrives.

tvoe is used in two roles and the importer keeps them apart: as a *metadata
provider* its Russian artwork, descriptions and cast are facts about the work;
as a *platform* its streams and tracks are facts about its copy.

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

Two halves, deliberately separate.

**Breadth — `fetch_tmdb_exports.py`, free.** TMDB publishes one gzipped
JSON-lines dump per entity type per day: id, original title, popularity. No
auth, no quota. Enough to know an id exists, what it is called originally and
how popular it is — which is all that resolving and ranking need. It carries no
credits, artwork, ratings or dates, so it does not replace detail fetching.

**Depth — `fetch_tmdb.py`, one request per title, opt-in.** Pass `--titles` for
exactly what a page needs, or `--limit N` for the N most-voted still missing, so
an interrupted run has still covered what people actually open. `--sweep`
exists for a deliberate backfill and refuses to run without `--yes`.

Per title: one `/find` plus one detail request carrying **12–13 append slots of
the 20 available** — credits, images, videos, external ids, keywords, release
dates, translations, alternative titles, watch providers, recommendations,
similar, reviews, and episode groups for series. The app currently sends six.

- No token here — the worker holds it.
- `fetch_log` records answers including misses, so nothing is ever asked twice.
- Cast is capped at 30 by billing order; crew is filtered by role (directors,
  writers, composers, DoPs, producers) rather than by count.
- 8 workers at 12 rps ≈ 5 titles/second.
- `--language ru-RU` by default: TMDB localizes person names and synopses while
  keeping ids stable, which is what makes RU↔EN pairing an id-join.

Two environment traps worth keeping:

- **Cloudflare answers the default `Python-urllib` user agent with 403**, which
  reads as "no match" everywhere downstream.
- **This network resolves `api.themoviedb.org`, `image.tmdb.org` *and*
  `files.tmdb.org` to `127.0.0.1`.** Everything TMDB goes through the worker,
  including the export dumps — that is what the `/p/exports/` route is for.

## Files

| File | Owns |
| --- | --- |
| `schema.sql` | The record. Uniqueness is enforced by `COALESCE` indexes, never by composite primary keys containing nullable columns — a NULL never equals a NULL in SQLite, so such a key silently accepts duplicates and every re-run doubles the table |
| `common.py` | Db handle, matching keys, title/person resolution, run logging |
| `sources.py` | One importer per dump. Adding a source is a function here plus a line in `ingest.py` |
| `ingest.py` | CLI and orchestration |
| `fetch_tmdb.py` | Depth: one detail request per title, opt-in |
| `fetch_tmdb_exports.py` | Breadth: TMDB's free daily id dumps |
| `Makefile` | The workflow |

`data/` is gitignored. `make backup` writes a gzipped SQL dump that is fine to
commit or push elsewhere.
