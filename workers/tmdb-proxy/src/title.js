/**
 * /v1/title/by/kinopub/{id}  and  /img/{kind}/{size}/kinopub/{id}
 *
 * The contract the client actually wanted: ask by kino.pub id, get everything,
 * never resolve anything yourself, never make a second call to find out whether
 * something exists.
 *
 * Two rules shape the whole file:
 *
 *   Always answer fast, from whatever is warm. A cold title still returns a
 *   usable document built from the hints the client sent, immediately — the
 *   client is drawing a screen and cannot wait for four providers.
 *
 *   Resolve in the background, once. `ctx.waitUntil` keeps the isolate alive
 *   after the response is sent, so the first person to open a cold title pays
 *   nothing and warms it for everyone after them.
 *
 * Hints are the reason this works without a database of our own being complete.
 * The client already holds the imdb id, the kinopoisk id, the original title,
 * the year — kino.pub hands them over on every item. Sending them costs nothing
 * and means a title we have never seen is still resolvable on the spot.
 */

const KINOPUB_POSTER = "https://m.staticpop.net/poster/item";
// kino.pub's own sizes, which are addressable from the id alone. This is the
// fallback that makes the image route incapable of returning a hole.
const KINOPUB_SIZE = { sm: "small", md: "medium", lg: "big", orig: "big", wide: "wide" };

const DOC_TTL = 60 * 60 * 24 * 30;

// The keyless kpapp.link proxy over Kinopoisk (docs/providers/kinopoisk-proxy.md).
// No auth, no documented quota — the cheap tier, safe to call on every cold
// resolve. Only `facts` is wired here for now; `staff`/`reviews`/`images` stay
// on the offline pipeline (tools/metadata-ingest/fetch_kinopoisk_proxy.py)
// until the live merge logic there is worth duplicating in a worker.
const KINOPOISK_PROXY = "https://kpapp.link/kpapi/films";

// --------------------------------------------------------------------- MD5
//
// Web Crypto's `crypto.subtle.digest` does not implement MD5 (not in the spec)
// — pushbr's URL scheme needs it anyway, so a small pure-JS implementation
// rides along. Standard bitwise MD5, RFC 1321.

function md5(input) {
  const bytes = new TextEncoder().encode(input);
  const bitLength = bytes.length * 8;
  const padded = new Uint8Array((((bytes.length + 8) >> 6) + 1) * 64);
  padded.set(bytes);
  padded[bytes.length] = 0x80;
  new DataView(padded.buffer).setUint32(padded.length - 8, bitLength >>> 0, true);
  new DataView(padded.buffer).setUint32(padded.length - 4, Math.floor(bitLength / 4294967296), true);

  const K = new Int32Array([
    -680876936, -389564586, 606105819, -1044525330, -176418897, 1200080426, -1473231341,
    -45705983, 1770035416, -1958414417, -42063, -1990404162, 1804603682, -40341101,
    -1502002290, 1236535329, -165796510, -1069501632, 643717713, -373897302, -701558691,
    38016083, -660478335, -405537848, 568446438, -1019803690, -187363961, 1163531501,
    -1444681467, -51403784, 1735328473, -1926607734, -378558, -2022574463, 1839030562,
    -35309556, -1530992060, 1272893353, -155497632, -1094730640, 681279174, -358537222,
    -722521979, 76029189, -640364487, -421815835, 530742520, -995338651, -198630844,
    1126891415, -1416354905, -57434055, 1700485571, -1894986606, -1051523, -2054922799,
    1873313359, -30611744, -1560198380, 1309151649, -145523070, -1120210379, 718787259,
    -343485551,
  ]);
  const S = [7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
             5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
             4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
             6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21];

  let [a0, b0, c0, d0] = [1732584193, -271733879, -1732584194, 271733878];
  const view = new DataView(padded.buffer);

  for (let chunk = 0; chunk < padded.length; chunk += 64) {
    const M = [];
    for (let j = 0; j < 16; j++) M.push(view.getUint32(chunk + j * 4, true));
    let [a, b, c, d] = [a0, b0, c0, d0];
    for (let i = 0; i < 64; i++) {
      let f, g;
      if (i < 16) { f = (b & c) | (~b & d); g = i; }
      else if (i < 32) { f = (d & b) | (~d & c); g = (5 * i + 1) % 16; }
      else if (i < 48) { f = b ^ c ^ d; g = (3 * i + 5) % 16; }
      else { f = c ^ (b | ~d); g = (7 * i) % 16; }
      const temp = d;
      d = c; c = b;
      const sum = (a + f + K[i] + M[g]) | 0;
      const rotated = (sum << S[i]) | (sum >>> (32 - S[i]));
      b = (b + rotated) | 0;
      a = temp;
    }
    a0 = (a0 + a) | 0; b0 = (b0 + b) | 0; c0 = (c0 + c) | 0; d0 = (d0 + d) | 0;
  }

  const toHex = (n) => {
    const bytes4 = new Uint8Array(4);
    new DataView(bytes4.buffer).setUint32(0, n, true);
    return Array.from(bytes4).map((b) => b.toString(16).padStart(2, "0")).join("");
  };
  return toHex(a0) + toHex(b0) + toHex(c0) + toHex(d0);
}

/** Mirrors common.pushbr_url() — same CDN, same hash, same input contract. */
function pushbrUrl(name) {
  const trimmed = (name || "").trim();
  if (!trimmed) return null;
  return `https://m.pushbr.com/actors/${md5(trimmed)}.jpg`;
}

export async function handleTitle(url, env, ctx) {
  const id = url.pathname.split("/").pop();
  if (!id) return json({ error: "bad_request", hint: "/v1/title/by/kinopub/{id}" }, 400);

  const hints = readHints(url);
  const stored = await readDocument(env, id);

  if (stored) {
    // Warm: answer from the store, and refresh in the background if the client
    // brought an id we did not have.
    const missingImdb = hints.imdb && !stored.ids?.imdb;
    const missingFacts = hints.kinopoisk && !stored.factsChecked;
    if (missingImdb || missingFacts) {
      ctx.waitUntil(resolveAndStore(env, id, hints, stored));
    }
    return json(stored, 200, { "X-Cache": "hit" });
  }

  // Cold: answer now from the hints, resolve behind the response.
  const draft = draftDocument(id, hints);
  ctx.waitUntil(resolveAndStore(env, id, hints, draft));
  return json(draft, 200, { "X-Cache": "miss" });
}

export async function handleImage(url, env, ctx) {
  // /img/{kind}/{size}/kinopub/{id}
  const [, , kind, size, namespace, rawId] = url.pathname.split("/");
  const id = (rawId || "").replace(/\.\w+$/, "");
  if (namespace !== "kinopub" || !id) {
    return json({ error: "bad_request", hint: "/img/{kind}/{size}/kinopub/{id}" }, 400);
  }

  const stored = await readDocument(env, id);
  const chosen = stored && pickArtwork(stored, kind);
  if (chosen) return Response.redirect(chosen, 302);

  // Nothing known yet: fall back to kino.pub's own artwork, which is always
  // addressable from the id, and resolve in the background so the next request
  // gets the good one. A layout never gets a hole while it waits.
  const hints = readHints(url);
  if (!stored) ctx.waitUntil(resolveAndStore(env, id, hints, draftDocument(id, hints)));

  const fallbackSize = KINOPUB_SIZE[size] || (kind === "backdrop" ? "wide" : "medium");
  return Response.redirect(`${KINOPUB_POSTER}/${fallbackSize}/${id}.jpg`, 302);
}

// ------------------------------------------------------------------ helpers

function readHints(url) {
  const get = (name) => url.searchParams.get(name) || undefined;
  return {
    imdb: get("imdb"),
    kinopoisk: get("kinopoisk"),
    title: get("title"),
    original: get("original"),
    year: get("year"),
    type: get("type"),
  };
}

/** What we can say about a title we have never seen, using only what the client sent. */
function draftDocument(id, hints) {
  return {
    version: 1,
    id: null,
    kind: hints.type === "series" ? "series" : hints.type ? "movie" : null,
    title: { ru: hints.title || null, original: hints.original || null },
    year: hints.year ? Number(hints.year) : null,
    ids: {
      kinopub: { value: id, confidence: 1, method: "client" },
      ...(hints.imdb ? { imdb: { value: hints.imdb, confidence: 1, method: "client" } } : {}),
      ...(hints.kinopoisk
        ? { kinopoisk: { value: hints.kinopoisk, confidence: 1, method: "client" } }
        : {}),
    },
    artwork: {
      poster: [{ source: "kinopub", url: `${KINOPUB_POSTER}/big/${id}.jpg`, lang: null }],
      backdrop: [{ source: "kinopub", url: `${KINOPUB_POSTER}/wide/${id}.jpg`, lang: null }],
    },
    ratings: [], synopsis: [], genres: [], countries: [], credits: [],
    seasons: [], trailers: [], awards: [], badges: [], copies: [],
    facts: [], reviews: [],
    // Honest about its own state: absent because nobody has asked yet, not
    // absent as a fact. The client hides sections on empty either way, but a
    // log tells the truth about which it was.
    pending: true,
  };
}

async function readDocument(env, id) {
  if (!env.DOCUMENTS) return null;         // KV not bound yet — degrade, do not fail
  return await env.DOCUMENTS.get(`title:kinopub:${id}`, { type: "json" });
}

async function writeDocument(env, id, document) {
  if (!env.DOCUMENTS) return;
  await env.DOCUMENTS.put(`title:kinopub:${id}`, JSON.stringify(document),
                          { expirationTtl: DOC_TTL });
}

/**
 * Resolve from hints and store. Runs after the response has gone out, so its
 * latency is nobody's problem — which is exactly why the client never has to
 * choose between "fast" and "complete".
 */
async function resolveAndStore(env, id, hints, base) {
  let document = base;

  // No key, no quota risk — safe to run on every cold resolve that has a
  // Kinopoisk hint. Gated on `factsChecked`, not on `ids.kinopoisk`: the draft
  // already carries the hinted id (see draftDocument), so gating on its
  // presence would mean this branch never runs — the actual first bug found
  // testing this live: a title with two real facts came back with zero.
  if (hints.kinopoisk && !base.factsChecked) {
    try {
      const facts = await kinopoiskProxyFacts(hints.kinopoisk);
      document = {
        ...document,
        factsChecked: true,
        ids: { ...document.ids, kinopoisk: { value: hints.kinopoisk, confidence: 1,
                                              method: "client" } },
        facts: facts?.items?.filter((item) => item.text).map((item) => ({
          source: "kinopoisk_proxy", text: item.text, spoiler: item.spoiler ? 1 : 0,
        })) || [],
      };
    } catch (_) {
      // Someone else's server, best-effort — a failure here must not block
      // TMDB, and must not be mistaken for "no facts" — leave factsChecked
      // unset so a later request tries again instead of caching a network blip.
    }
  }

  if (!hints.imdb || !env.TMDB_READ_TOKEN) {
    if (document !== base) await writeDocument(env, id, document);
    return;
  }

  try {
    const found = await tmdb(env, `/3/find/${hints.imdb}`, { external_source: "imdb_id" });
    const preferTv = base.kind === "series";
    const order = preferTv ? ["tv", "movie"] : ["movie", "tv"];
    let match = null, mediaType = null;
    for (const type of order) {
      const results = found?.[`${type}_results`];
      if (results?.length) { match = results[0]; mediaType = type; break; }
    }
    if (!match) {
      if (document !== base) await writeDocument(env, id, document);
      return;
    }

    const append = mediaType === "tv"
      ? "aggregate_credits,images,videos,external_ids,content_ratings,keywords,watch/providers"
      : "credits,images,videos,external_ids,keywords,release_dates,watch/providers";
    const details = await tmdb(env, `/3/${mediaType}/${match.id}`, {
      language: "ru-RU", append_to_response: append,
      include_image_language: "ru,en,null",
    });
    if (!details) {
      if (document !== base) await writeDocument(env, id, document);
      return;
    }

    await writeDocument(env, id, mergeTMDB(document, mediaType, match.id, details));
  } catch (_) {
    // Background work: a failure must never be visible, and must not poison the
    // store with a half-built document.
    if (document !== base) await writeDocument(env, id, document);
  }
}

/** kpapp.link/kpapi/films/{id}/facts — see docs/providers/kinopoisk-proxy.md. */
async function kinopoiskProxyFacts(kinopoiskId) {
  const response = await fetch(`${KINOPOISK_PROXY}/${kinopoiskId}/facts`, {
    headers: { Accept: "application/json" },
    cf: { cacheTtl: 60 * 60 * 24 * 14, cacheEverything: true },
  });
  return response.ok ? await response.json() : null;
}

async function tmdb(env, path, params) {
  const url = new URL(path, "https://api.themoviedb.org");
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  const response = await fetch(url.toString(), {
    headers: { Accept: "application/json", Authorization: `Bearer ${env.TMDB_READ_TOKEN}` },
    cf: { cacheTtl: 21600, cacheEverything: true },
  });
  return response.ok ? await response.json() : null;
}

const IMAGE_BASE = "https://image.tmdb.org/t/p/original";

function mergeTMDB(base, mediaType, tmdbId, details) {
  const document = { ...base, pending: false, built_at: new Date().toISOString() };
  document.ids = { ...document.ids, tmdb: { value: `${mediaType}/${tmdbId}`, confidence: 1,
                                            method: "find:imdb" } };
  const external = details.external_ids || {};
  for (const [namespace, key] of [["wikidata", "wikidata_id"], ["tvdb", "tvdb_id"]]) {
    if (external[key]) {
      document.ids[namespace] = { value: String(external[key]), confidence: 1,
                                  method: "tmdb:external_ids" };
    }
  }

  document.title = {
    ru: details.name || details.title || document.title.ru,
    original: details.original_name || details.original_title || document.title.original,
  };
  document.kind = mediaType === "tv" ? "series" : "movie";

  // One per language, capped to ru / en / textless — see capArtwork. The
  // kino.pub fallback the draft carried is appended last, so it only survives
  // the cap if TMDB left a language slot empty.
  const images = details.images || {};
  const toAssets = (list) => (list || [])
    .filter((a) => a.file_path)
    .sort((a, b) => (b.width || 0) - (a.width || 0))
    .map((a) => ({ source: "tmdb", url: IMAGE_BASE + a.file_path, lang: a.iso_639_1 || null,
                   width: a.width, height: a.height }));
  document.artwork = {
    poster: capArtwork([...toAssets(images.posters), ...(document.artwork.poster || [])]),
    backdrop: capArtwork([...toAssets(images.backdrops), ...(document.artwork.backdrop || [])]),
    logo: capArtwork(toAssets(images.logos)),
  };

  if (details.vote_count) {
    document.ratings = [{ source: "tmdb", value: details.vote_average,
                          votes: details.vote_count, scale: 10 }];
  }
  if (details.overview) {
    document.synopsis = [{ source: "tmdb", lang: "ru", variant: "full",
                           text: details.overview }];
  }
  document.genres = (details.genres || []).map((g) => ({ source: "tmdb", name: g.name }));

  // `name` is localized by the request's `language` (ru-RU below), so it is
  // the Russian spelling, not English — mislabeling it name_en would split
  // this person from the identical Russian name a Kinopoisk fetch might
  // supply later, same bug fixed in fetch_tmdb.py's _credit_names(). Prefer
  // `original_name` for the English slot when it actually differs.
  const credits = details.aggregate_credits || details.credits || {};
  document.credits = (credits.cast || [])
    .sort((a, b) => (a.order ?? 999) - (b.order ?? 999))
    .slice(0, 30)
    .map((person) => {
      const nameRu = person.name || null;
      const nameEn = person.original_name && person.original_name !== person.name
        ? person.original_name : null;
      const tmdbPhoto = person.profile_path ? IMAGE_BASE + person.profile_path : null;
      // pushbr is free (a hash of a name we already have) and, for this
      // majority-RU/CIS-facing catalogue, usually the better default — see
      // policies/metadata-architecture's photo precedence note. TMDB's photo
      // still rides along as the fallback candidate.
      const photos = [pushbrUrl(nameRu), tmdbPhoto].filter(Boolean);
      return {
        department: "actor",
        character: person.roles?.[0]?.character ?? person.character ?? null,
        ord: person.order ?? null,
        episode_count: person.total_episode_count ?? null,
        sources: ["tmdb"],
        name_en: nameEn, name_ru: nameRu,
        photos,
      };
    });

  document.trailers = (details.videos?.results || [])
    .filter((video) => video.key)
    .map((video) => ({
      source: "tmdb", source_key: video.key, kind: (video.type || "trailer").toLowerCase(),
      name: video.name, lang: video.iso_639_1, official: video.official ? 1 : 0,
      url: video.site === "YouTube" ? `https://www.youtube.com/watch?v=${video.key}` : null,
    }));

  document.seasons = (details.seasons || [])
    .filter((season) => season.season_number != null)
    .map((season) => ({
      number: season.season_number, name: season.name, synopsis: season.overview || null,
      air_date: season.air_date, end_date: null, episode_cnt: season.episode_count,
      poster: season.poster_path ? IMAGE_BASE + season.poster_path : null,
      source: "tmdb", episodes: [], ratings: [],
    }));

  return document;
}

// ru first (our primary audience), then en, then textless (no title baked
// into the image — the one you want under your own logo overlay). Any other
// language is dropped: it does carry text, just not one we asked for, so
// folding it into "textless" would be a lie.
const ARTWORK_LANG_ORDER = ["ru", "en", null];

/** One image per (kind, language), at most 3. First match per language wins,
 * so pass assets already sorted by trust/width for the best pick to survive. */
function capArtwork(assets) {
  const picked = new Map();
  for (const asset of assets) {
    const lang = asset.lang ?? null;
    if (!ARTWORK_LANG_ORDER.includes(lang) || picked.has(lang)) continue;
    picked.set(lang, { ...asset, lang });
    if (picked.size === ARTWORK_LANG_ORDER.length) break;
  }
  return ARTWORK_LANG_ORDER.filter((lang) => picked.has(lang)).map((lang) => picked.get(lang));
}

/** Best artwork of a kind: our precedence, applied here so the client has none. */
function pickArtwork(document, kind) {
  const list = document.artwork?.[kind];
  if (!list?.length) return null;
  const russian = list.find((asset) => asset.lang === "ru");
  return (russian || list[0]).url;
}

function json(body, status, extra = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "public, max-age=300",
      "Access-Control-Allow-Origin": "*",
      ...extra,
    },
  });
}
