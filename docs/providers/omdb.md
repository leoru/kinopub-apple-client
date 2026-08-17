# OMDb

**Status: probed.** 🔎 marks facts captured from 150 real responses (the 150 highest-IMDb-vote
titles in our record, 2026-08-17). The run cost 150 of the day's 1 000 and resolved 150/150 — no
misses at all at the popular end, which is the point of fetching in vote order.

**Auth:** `apikey` query parameter. Ours (server-side) — free tier requires an email signup.
**Quota:** **1 000 requests/day** on the free tier. Exhaustion returns HTTP **200** with
`{"Response":"False","Error":"Request limit reached!"}`.
**Coverage:** 🔎 **movies only, for the part we actually want.** Of 138 movies, 136 carried Rotten
Tomatoes and 137 Metacritic. Of 11 series, **1 had RT and 0 had Metacritic**. The critic scores are
a movie feature; for series this provider has nothing we do not already hold.

🔎 **Geography is not the constraint** — my pre-probe guess that CIS and small-European titles would
lack RT was wrong. France 8/8, Germany 8/8, Canada 8/8, Japan 3/3, Hong Kong 4/4, New Zealand 4/4,
Jordan 2/2 all carried RT. Type decides, not country.

Otherwise it is a *thin* projection of IMDb, not IMDb. One flat record per title, no cast ids, no
images beyond one poster, no keywords.
**Ids accepted:** IMDb id only (`i=tt…`), or a title string (`t=` exact, `s=` search). **No TMDB,
no Kinopoisk, no TVDB.** It sits downstream of identity, never resolves it.
**Integration kind:** system.
**Import capabilities:** none. No dumps, no bulk, no changes feed. Strictly one request per title.
**Images:** one `Poster` URL on `m.media-amazon.com`, and it carries a size/crop segment
(`…_V1_SX300.jpg`). **Derived, not an original** — under the policy's URL-stability rule this is the
kind we do not treat as durable. We have better posters from four sources already.

## Why it earns a slot at all

Exactly one reason: **Rotten Tomatoes and Metacritic in a single call**, which nothing else we
integrate provides. IMDb rating and votes we already hold from the kino.pub snapshot for 45 950
titles, so those are a cross-check, not new data.

Everything else it returns is a weaker copy of something we have: credits as comma-joined strings
with no ids, one derived poster, plot text, awards as English prose.

## Endpoints

There is effectively one.

| Request | Returns | We take | We skip, and why |
| --- | --- | --- | --- |
| `?i=tt0111161&plot=full` | One flat title record | `Ratings[]`, `Metascore`, `imdbRating`, `imdbVotes`, `BoxOffice`, `Awards` | Everything else duplicates a better source |
| `?i=tt…&Season=1&Episode=1` | One episode record incl. `imdbRating` | — see below | Per-episode ratings, but at one request each |
| `?s=…` | Search results, 10 per page | — | We never resolve identity here |
| `?t=…&y=…` | Title lookup | — | Same |

**Per-episode ratings are real but unaffordable here.** A 62-episode series is 62 requests out of a
1 000/day budget. IMDb's public dataset dump gives the same numbers for the whole world in one file
and stays the correct source for that; TMDB carries `vote_average` per episode too. OMDb's episode
endpoint is a fallback for a single hot title, not a strategy.

## Models 🔎 probed

One object, and the trap is that **every value is a string, including the numbers**, with the
literal `"N/A"` standing in for null.

🔎 **The shape differs by `Type`, so nothing may be a required field:**

| | movie | series | episode |
| --- | --- | --- | --- |
| `BoxOffice`, `DVD`, `Production`, `Website` | present | **absent** | absent |
| `totalSeasons` | absent | present | absent |
| `Season`, `Episode`, `seriesID` | absent | absent | present |

🔎 `Production` and `Website` were `"N/A"` on **138 of 138** payloads that carried them, and `DVD` on
137 of 138. Documented, dead in practice — do not model them.

| Field | Documented shape | Note |
| --- | --- | --- |
| `Response` | `"True"` / `"False"` | **Errors are HTTP 200.** A failed lookup is a 200 carrying `Response: "False"` and an `Error` string. Anything that trusts the status code records a success |
| `Error` | string | `"Movie not found!"`, `"Request limit reached!"`, `"Invalid API key!"` — three very different conditions in one shape |
| `imdbRating` | `"9.3"` | string |
| `imdbVotes` | `"2,900,123"` | **comma-grouped string**; parse before use |
| `Metascore` | `"80"` / `"N/A"` | Metacritic critics |
| `Ratings[]` | `[{Source, Value}]` | `Source` ∈ `Internet Movie Database` (`"9.3/10"`), `Rotten Tomatoes` (`"91%"`), `Metacritic` (`"80/100"`). **Three different scales in one array**, as text. 🔎 Absent sources are **omitted from the array**, never present as `"N/A"` — verified across 150 payloads |
| `BoxOffice` | `"$28,767,189"` | US domestic only, currency-formatted |
| `Awards` | `"Won 2 Oscars. 157 wins & 220 nominations total"` | English prose. Kinopoisk gives us this structured; do not parse it |
| `Rated` | `"R"` | US certification |
| `Runtime` | `"142 min"` | with unit |
| `Genre`, `Director`, `Writer`, `Actors`, `Language`, `Country` | comma-joined strings | **No ids on anything.** Useless for the person table by design |
| `Released`, `DVD` | `"14 Oct 1994"` | day-month-year text |
| `Type` | `movie` / `series` / `episode` | |
| `totalSeasons` | string | series only |
| `Production`, `Website` | often `"N/A"` | documented but reportedly discontinued — verify |

## Quirks

🔎 **Errors are HTTP 200.** A dummy key returned `Response:"False"` in the same shape as a missing
title. Treating that as "no such title" writes a permanent negative into `fetch_log` and the title is
never asked again — the exact failure the log exists to prevent. Only `"Movie not found!"` is an
answer *about the title*; `"Invalid API key!"` and `"Request limit reached!"` are answers about us
and must stop the run without writing.

🔎 **Our own data has episode-level IMDb ids in it.** `tt0841700` came back as
`Type: "episode"` with every field `"N/A"` — so at least one row in the kino.pub snapshot carries an
episode id where a title id belongs. Worth a sweep of the record for others.

Still open:

- Whether `imdbVotes` grouping is locale-stable.
- Behaviour at exactly 1 000 requests, and whether the counter is UTC-midnight or rolling.

## Verdict

Take: `Ratings[]` (all three, each with its own scale recorded), `Metascore`, `BoxOffice`.
Cross-check: `imdbRating` / `imdbVotes` against the kino.pub snapshot.
Skip: credits, poster, plot, genres, awards prose, dates — every one has a better source already.

**Fetch lazily, ordered by vote count.** 1 000/day against 53 210 titles is 53 days for a full pass,
so a sweep is not an option even if we wanted one; this is the provider that makes the lazy rule
non-negotiable rather than merely correct.

🔎 And skip series entirely: 11 of them returned one RT score between them. Spending a request on a
series buys an IMDb number we already hold.
