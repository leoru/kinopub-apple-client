/**
 * TMDB proxy.
 *
 * GET /3/...  → api.themoviedb.org/3/...  (Bearer secret)
 * GET /t/p/... → image.tmdb.org/t/p/...   (no auth; bypasses local image.tmdb.org blocks)
 */

const TMDB_API = "https://api.themoviedb.org";
const TMDB_IMAGE = "https://image.tmdb.org";

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      return json({ error: "method_not_allowed" }, 405);
    }

    const url = new URL(request.url);

    if (url.pathname.startsWith("/t/p/")) {
      return proxyImage(url, ctx);
    }

    if (url.pathname.startsWith("/3/")) {
      return proxyAPI(url, env, ctx);
    }

    return json({
      error: "not_found",
      hint: "use /3/... for API or /t/p/{size}/{path} for images",
    }, 404);
  },
};

async function proxyAPI(url, env, ctx) {
  const token = env.TMDB_READ_TOKEN;
  if (!token) {
    return json({ error: "misconfigured", hint: "TMDB_READ_TOKEN secret missing" }, 500);
  }

  const upstreamBase = env.TMDB_API_BASE || TMDB_API;
  const upstreamURL = new URL(url.pathname + url.search, upstreamBase);

  const cache = caches.default;
  const cacheKey = new Request(upstreamURL.toString(), { method: "GET" });
  const cached = await cache.match(cacheKey);
  if (cached) return withCORS(cached);

  const upstream = await fetch(upstreamURL.toString(), {
    method: "GET",
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${token}`,
    },
  });

  const ttl = Number(env.CACHE_TTL_SECONDS || 21600);
  const headers = new Headers(upstream.headers);
  headers.set("Cache-Control", `public, max-age=${ttl}`);
  headers.set("Access-Control-Allow-Origin", "*");

  const response = new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers,
  });

  if (upstream.status >= 200 && upstream.status < 300) {
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
  }

  return response;
}

async function proxyImage(url, ctx) {
  // /t/p/w185/abc.jpg → https://image.tmdb.org/t/p/w185/abc.jpg
  const upstreamURL = TMDB_IMAGE + url.pathname;
  const cache = caches.default;
  const cacheKey = new Request(upstreamURL, { method: "GET" });
  const cached = await cache.match(cacheKey);
  if (cached) return withCORS(cached);

  const upstream = await fetch(upstreamURL, {
    method: "GET",
    headers: { Accept: "image/*,*/*" },
  });

  const headers = new Headers(upstream.headers);
  headers.set("Cache-Control", "public, max-age=604800");
  headers.set("Access-Control-Allow-Origin", "*");

  const response = new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers,
  });

  if (upstream.status >= 200 && upstream.status < 300) {
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
  }

  return response;
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
    "Access-Control-Allow-Headers": "Accept",
  };
}

function withCORS(response) {
  const headers = new Headers(response.headers);
  headers.set("Access-Control-Allow-Origin", "*");
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

function json(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(),
    },
  });
}
