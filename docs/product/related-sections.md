# Related sections — what a detail page recommends

**prd — Every type recommends something.** A film and a series were the only kinds with a related
area worth the name; a concert, a TV show or a stand-up set opened a page that ended after the
synopsis. Whatever the type, the page must offer somewhere to go next.

Order, top to bottom — each shelf absent when its query came back empty:

| # | Shelf | Query |
| --- | --- | --- |
| 1 | Similar | `/v1/items/similar` |
| 2 | Author — "More by This Director" / "…These Creators" | `director=` every credited name (max 3) |
| 3 | Cast | `cast=`, per the rules below |
| 4 | Collections — one shelf per collection, titled by it | which collections hold this item, then each collection's items |
| 5 | Genre floor | same type + one genre |

## The cast shelf, per kind

**prd — Concert:** ask **every** performer, and ask for **concerts** (`type=concert&cast=…`). A
singer's filmography is not what someone who just watched a concert wants next. Header: *More by
This Artist* / *More from These Artists*.

**prd — Stand-up:** ask **every** participant, with no type filter, and float **films and series**
to the front. A comic's other work is the interesting answer and it is usually not another set.
Header: *More by This Comedian* / *More from These Comedians*. **idea:** inside that ordering, put
stand-up first when the participant has some.

**prd — Everything else:** the first billed actor only, named in the header (*More with …*). ORing
fifteen credited names asks for half the catalogue.

Preference is an **ordering, never a filter** — nothing is hidden, it only stops leading.

## Collections

**prd** — when a title belongs to collections, each becomes its own shelf, titled by the collection,
its header opening the collection's page. Capped at **3**: reading what is in one costs a request of
its own.

**Not verified.** The endpoint is `items/collections/{id}` — captured from the PWA on its
`api2/v1.1` branch, and we ask our own host for the same path. Whether it answers there is unknown;
a failure means no collection shelves and a log line (`item collections id=… count=…`).

## The genre floor

**prd** — when *nothing* above produced a shelf, ask for more of the same **type** and one genre,
by Kinopoisk rating. Someone on a TV show wants other shows, not a film that shares a genre with it,
so the type is kept — `/tvshow?genre=123`, in the web client's terms.

Which genre, when a title carries six: the one that **decided its kind** (stand-up over the Comedy
it is also filed under, animation over Adventure), else the first credited. `/v1/items` takes one
genre per request.

**idea — category/categories.** "Same type *and* its categories/genres" was asked for; only one
genre is queryable today, so the rest of that is unbuilt.

## Shared rules

One card per film everywhere (the 3D and flat entries of one title collapse), the current title is
never in its own shelves, and a title already on the author shelf is dropped from the cast shelf.
Every shelf is best-effort: a failure is a log line and an absent section, never an error over the
artwork.

## Verification

All of the above is **prd** — it builds on tvOS and iOS, the rules are unit-tested
(`RelatedShelfPolicyTests`, `PreferredTypesTests`), and none of it has been watched on a device.
The collections endpoint in particular has never answered us once.
