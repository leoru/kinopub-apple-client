# TMDB proxy (Cloudflare Worker)

Transparent forwarder for The Movie Database API v3 **and** image CDN. The app never
sees the read token. Images go through the worker too (`/t/p/…`) so local DNS/proxy
hijacks of `image.tmdb.org` (→ `127.0.0.1`) do not break cast photos and logos.

## Deploy

```bash
cd workers/tmdb-proxy
npx wrangler secret put TMDB_READ_TOKEN   # paste the TMDB API Read Access Token
npx wrangler deploy
```

Copy the worker URL (e.g. `https://kinopub-tmdb-proxy.<account>.workers.dev`) into the
app's `Info.plist` as `TMDBProxyBaseURL` — no trailing slash.

## Behaviour

| Client request | Upstream |
| --- | --- |
| `GET {proxy}/3/find/tt0903747?external_source=imdb_id` | `GET https://api.themoviedb.org/3/find/…` with `Authorization: Bearer …` |
| `GET {proxy}/t/p/w185/abc.jpg` | `GET https://image.tmdb.org/t/p/w185/abc.jpg` (no auth) |

Successful GET responses are edge-cached for `CACHE_TTL_SECONDS` (default 6 hours).
4xx/5xx are not cached.

## Local

```bash
npx wrangler dev
```

Set the secret the same way, or put `TMDB_READ_TOKEN` in `.dev.vars` (gitignored).
