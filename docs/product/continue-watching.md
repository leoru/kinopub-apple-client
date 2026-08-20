# Continue Watching

What the Home row offers, in what order, and what it deliberately leaves out.

The row is one merge of `/v1/watching/movies`, `/v1/watching/serials` (subscribed and not) and
`/v1/history`, plus local resume points the server has not heard about yet. Field-level detail of
those payloads is in [docs/providers/kinopub/watching.md](../providers/kinopub/watching.md); the
mechanics are on `ContinueWatchingOrder` and `ContinueWatchingLocalOverlay`.

## What the row is for

**prd** — It is "carry on with what you were doing", not the watching list. The whole watching list
is the Library tab, which is where the row's header chevron goes.

**prd** — It is capped (`ContinueWatchingOrder.maxItems`). `/v1/watching/serials` returns every
unfinished serial on the account — hundreds, for a long-lived one — and past the first screen that
is a list of things abandoned years ago. A sideways scroll with no end defeats the point of the row.

## Order

**prd** — Buckets first, in this order: played in the last week · on the watchlist with new episodes
· the rest of the watchlist · everything else unfinished.

**prd** — Inside a bucket, most recently played wins.

**prd** — Where neither title has a date, **the smaller backlog wins** — `new`, the count of
unwatched episodes. One or two waiting is a title being followed; a hundred and seventy is a title
abandoned. This exists because the watching endpoints carry **no timestamp at all**: the only dates
come from the page of `/v1/history` we fetch, so most of the row is undated and the tie used to fall
to the server's own list order. That put cartoons last touched years ago above a show with one new
episode waiting.

**prd** — A film counts as backlog zero. It has no episode counters, and a half-watched film is one
press from finished, so it belongs above a serial with a season to go.

## What stays out

**prd** — A title only *local* progress knows about needs `WatchProgress.enterContinueWatchingSeconds`
before it earns a card. The 10 s "has started" floor is for painting a progress bar on a card that is
already there; a card the server never listed has nothing to take it back out again, and a trailer
sampled for a minute is not something to carry on with.

**prd** — A finished film leaves the row. A finished *episode* does not remove the series — it steps
it to the next episode.

**prd** — The row never pages. "Page 2" of a four-source merge has no meaning on the server.

## Open

Ordering below the first few titles is still guesswork, because the backlog count is a proxy for
"am I following this" rather than the thing itself. Dates for more of the row would need more of
`/v1/history` (`perpage` maxes at 50, and one page of 20 already measured ~96 KB on a cold launch),
so it is a payload trade, not a free improvement. See [ROADMAP.md](../../ROADMAP.md).
