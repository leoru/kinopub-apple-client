# OMDb

**Status: sheet written from the vendor's documentation only — nothing here is probed yet.**
We hold no key. Every table below is marked ⚠️ until a first run captures real responses; the
verified ones get 🔎 like the kino.pub sheets. Written before integrating, per rule zero.

**Auth:** `apikey` query parameter. Ours (server-side) — free tier requires an email signup.
**Quota:** **1 000 requests/day** on the free tier. Exhaustion returns HTTP **200** with
`{"Response":"False","Error":"Request limit reached!"}`.
**Coverage:** whatever IMDb covers, which is nearly everything — but it is a *thin* projection of
IMDb, not IMDb. One flat record per title. No cast ids, no images beyond one poster, no keywords.
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

## Models ⚠️ unverified

One object, and the trap is that **every value is a string, including the numbers**, with the
literal `"N/A"` standing in for null.

| Field | Documented shape | Note |
| --- | --- | --- |
| `Response` | `"True"` / `"False"` | **Errors are HTTP 200.** A failed lookup is a 200 carrying `Response: "False"` and an `Error` string. Anything that trusts the status code records a success |
| `Error` | string | `"Movie not found!"`, `"Request limit reached!"`, `"Invalid API key!"` — three very different conditions in one shape |
| `imdbRating` | `"9.3"` | string |
| `imdbVotes` | `"2,900,123"` | **comma-grouped string**; parse before use |
| `Metascore` | `"80"` / `"N/A"` | Metacritic critics |
| `Ratings[]` | `[{Source, Value}]` | `Source` ∈ `Internet Movie Database` (`"9.3/10"`), `Rotten Tomatoes` (`"91%"`), `Metacritic` (`"80/100"`). **Three different scales in one array**, as text |
| `BoxOffice` | `"$28,767,189"` | US domestic only, currency-formatted |
| `Awards` | `"Won 2 Oscars. 157 wins & 220 nominations total"` | English prose. Kinopoisk gives us this structured; do not parse it |
| `Rated` | `"R"` | US certification |
| `Runtime` | `"142 min"` | with unit |
| `Genre`, `Director`, `Writer`, `Actors`, `Language`, `Country` | comma-joined strings | **No ids on anything.** Useless for the person table by design |
| `Released`, `DVD` | `"14 Oct 1994"` | day-month-year text |
| `Type` | `movie` / `series` / `episode` | |
| `totalSeasons` | string | series only |
| `Production`, `Website` | often `"N/A"` | documented but reportedly discontinued — verify |

## Quirks to confirm on first run ⚠️

- Whether `Ratings[]` omits absent sources or includes them as `N/A`.
- Whether `Rotten Tomatoes` appears for non-US titles at all — suspicion is that CIS and small
  European titles have neither RT nor Metacritic, which would make coverage the deciding fact about
  how much this provider is worth.
- Whether `imdbVotes` grouping is locale-stable.
- Behaviour at exactly 1 000 requests, and whether the counter is UTC-midnight or rolling.

## Verdict

Take: `Ratings[]` (all three, each with its own scale recorded), `Metascore`, `BoxOffice`.
Cross-check: `imdbRating` / `imdbVotes` against the kino.pub snapshot.
Skip: credits, poster, plot, genres, awards prose, dates — every one has a better source already.

**Fetch lazily, ordered by what people actually open.** 1 000/day against 53 210 titles is 53 days
for a full pass, so a sweep is not an option even if we wanted one; this is the provider that makes
the lazy rule non-negotiable rather than merely correct.
