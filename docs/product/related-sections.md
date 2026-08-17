# Related sections — what a detail page recommends

**prd — Every type recommends something.** A film and a series were the only kinds with a related
area worth the name; a concert, a TV show or a stand-up set opened a page that ended after the
synopsis. Whatever the type, the page must offer somewhere to go next.

Order, top to bottom — each shelf absent when its query came back empty:

| # | Shelf | Query |
| --- | --- | --- |
| 1 | Similar | `/v1/items/similar` |
| 2 | Author — "More by This Director" / "…These Creators" | `director=`, **one request per name**, max 2, merged |
| 3 | Cast | `cast=`, same one-per-name rule, per the rules below |
| 4 | Collections — one shelf per collection, titled by it | which collections hold this item, then each collection's items |
| 5 | Genre floor | same type + genres, **only when 1–4 all came back empty** |

**verified 2026-08-17 — a comma does not work on `cast` / `director`.** They match the credits field
as written, so `director=Фил Лорд,Кристофер Миллер` answers an empty list where either name alone
answers a filmography. Two names is two requests, merged and collapsed by film. `genre` is the
opposite: a comma there *is* OR, which is what the floor uses.

## The cast shelf, per kind

**prd — Concert:** ask the **two** billed performers, and ask for **concerts**
(`type=concert&cast=…`). A singer's filmography is not what someone who just watched a concert wants
next. Header: *More by This Artist* / *More from These Artists*.

**prd — Stand-up:** ask the **two** billed participants, with no type filter, and float **films and
series** to the front. A comic's other work is the interesting answer and it is usually not another
set. Header: *More by This Comedian* / *More from These Comedians*. **idea:** inside that ordering,
put stand-up first when the participant has some.

**prd — Animation (anime and cartoons): no cast shelf at all.** kino.pub's `cast` on anything drawn
is the **voice actors** — a shelf headed "More with Уэмура Юто" is a name the viewer never heard
over a face that was never on screen.

**prd — Everything else:** the first billed actor only, named in the header (*More with …*). Two
names is a shelf; a film credits fifteen, and each one would be its own request.

Preference is an **ordering, never a filter** — nothing is hidden, it only stops leading.

## Collections

**prd** — when a title belongs to collections, each becomes its own shelf, titled by the collection,
its header opening the collection's page. Capped at **3**: reading what is in one costs a request of
its own.

**verified 2026-08-17 — this method is not on our host.** `/v1/items/collections/248` answers **404**
on `api.service-kp.com`; the PWA reads it from `api.ios-kp.store/api2/v1.1/items/collections/{id}`,
which is where the request goes now (`Endpoint.baseURLOverride`, the only endpoint using it).
Whether the branch accepts our token is still unconfirmed — a failure is silence and a log line
(`item collections id=… count=…`).

## The genre floor

**prd — last resort, and it must actually be last.** It fires only when similar, both credit shelves
*and* the collections have **answered** and all came back empty. Waiting for the answer, not for the
value, is the whole rule: firing early asked for the genres of `MediaItem.mock()` and put a
"More in Comedy" shelf of cartoons on a concert page.

**prd — the same type is kept.** Someone on a TV show wants other shows, not a film that shares a
genre with it — `/tvshow?genre=…`, in the web client's terms.

**prd — how many genres.** A film asks for **one**: "more comedy" under a comedy is a truism and its
other shelves carry the page. Everything else asks for **all of them at once** (max 4, comma-OR),
because a title filed under six genres is described by the combination, not by whichever one came
first. The single-genre pick is the one that **decided the kind** (stand-up over the Comedy it is
also filed under), else the first credited. If the multi-genre request answers nothing, it retries
with that one genre rather than leaving the page bare.

**prd — it is the web client's own genre page.** Type, genres, country and a `period` window,
`sort=-updated` — `?genre=23,26&country=1&period=month`. The point is what there is to watch now,
not the all-time top of a genre (sorting by Kinopoisk rating is how a page about a 2026 anime
recommended Friends).

**prd — narrowest first, then widen.** A narrow query on a thin genre answers nothing, and an empty
shelf is what this whole mechanism exists to prevent, so it asks up to three times and stops at the
first answer: country + genres + this month → genres alone → the one genre that describes the title
best.

## Shared rules

One card per film everywhere (the 3D and flat entries of one title collapse), the current title is
never in its own shelves, and a title already on the author shelf is dropped from the cast shelf.
Every shelf is best-effort: a failure is a log line and an absent section, never an error over the
artwork.

## Verification

The comma behavior on `cast` / `director` is **verified** — seen answering empty on a live request.
Everything else is **prd**: it builds on tvOS and iOS and the rules are unit-tested
(`RelatedShelfPolicyTests`, `CreditQueryTests`, `ShelfQueryParameterTests`, `PreferredTypesTests`),
but the shelves themselves have only been looked at in the running app, and:

- the collections branch host is new and its answer to our token has not been seen yet;
- `genre=5,23,101` as OR is **unverified** — the fallback exists because of that. `genre floor
  id=… genres=… items=…` in the log is what will settle it.
