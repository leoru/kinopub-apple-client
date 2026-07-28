#!/usr/bin/env python3
"""
tvoe.live scraper v3 — full catalog + details (+ optional inline images)

API notes (learned the hard way):
  - /catalog (v1) silently ignores `from` — every page returns the first 100 items.
  - /v2/catalog paginates with `limit` + `skip` (accumulated item count), same as the site's own client.
  - /_next/image?url=<relative path> → 400. The optimizer needs the absolute CDN URL
    (https://static.cdn.tvoe.live/images/...). Direct originals also work on the CDN host.

Output: tools/tvoe_data/
Images are downloaded separately: python3 download_tvoe_images.py (parallel, resumable).
"""

import json
import re
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import quote

try:
    import requests
except ImportError:
    print("pip3 install --break-system-packages requests")
    sys.exit(1)

BUILD_ID = "vNn_WdW65SRZRBOCj4GSP"
API = "https://api.tvoe.live/v2/catalog"
SITE = "https://tvoe.live"
CDN = "https://static.cdn.tvoe.live"
HLS_CDN = "https://hls.cdn.tvoe.live"
PAGE_SIZE = 100
WORKERS = 2           # Qrator bans by IP after parallel bursts — keep it low
DETAIL_DELAY = 0.25   # seconds between detail requests per worker
MAX_CONSEC_FAILS = 100
OUT = Path("/Users/sasha/Documents/GitHub/kinopub-apple-client/tools/tvoe_data")
IMG = OUT / "images"

IMG_SIZES = {"poster": "w=384&q=75", "cover": "w=1280&q=75", "logo": "w=256&q=90"}

PROXY = None  # --proxy http://user:pass@host:port (RU IP required, site is geo-locked)

_local = threading.local()


def session():
    if not hasattr(_local, "ses"):
        _local.ses = requests.Session()
        _local.ses.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
        if PROXY:
            _local.ses.proxies = {"http": PROXY, "https": PROXY}
    return _local.ses


def fetch_catalog(cat):
    items, skip, seen = [], 0, set()
    while True:
        r = session().get(f"{API}?categoryAlias={cat}&limit={PAGE_SIZE}&skip={skip}", timeout=20)
        r.raise_for_status()
        data = r.json()
        batch = data.get("items", [])
        total = data.get("totalSize", 0)
        fresh = [b for b in batch if b.get("_id") not in seen]
        if not fresh:
            break
        for b in fresh:
            seen.add(b.get("_id"))
        items.extend(fresh)
        print(f"  skip={skip}: +{len(fresh)} (total={total})")
        skip += len(batch)
        if len(fresh) < len(batch):
            print(f"  ⚠ page contained {len(batch) - len(fresh)} duplicates — API misbehaving, stopping")
            break
        if skip >= total or not batch:
            break
        time.sleep(0.08)
    return items


def current_build_id():
    try:
        r = session().get(f"{SITE}/filmy", timeout=20)
        r.raise_for_status()
        m = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', r.text, re.S)
        if m:
            return json.loads(m.group(1)).get("buildId") or BUILD_ID
    except Exception:
        pass
    return BUILD_ID


def fetch_detail(item, build_id):
    slug = item.get("url", "").strip("/").split("/")[-1] if item.get("url") else ""
    if not slug:
        return item, {}, None
    try:
        r = session().get(f"{SITE}/_next/data/{build_id}/p/{slug}.json", timeout=20)
        r.raise_for_status()
        time.sleep(DETAIL_DELAY)
        return item, r.json().get("pageProps", {}).get("data", {}), None
    except Exception as e:
        return item, {}, f"{slug}: {e}"


def _attach_hls_urls(node):
    """Walk videos structure; add playable hlsUrl to anything with src+version."""
    if isinstance(node, dict):
        src, version = node.get("src"), node.get("version")
        if isinstance(src, str) and src.startswith("/"):
            if version == 3:
                node["hlsUrl"] = f"{HLS_CDN}{src}/hls/0/master.m3u8"
            elif version == 2:
                node["hlsUrl"] = f"{HLS_CDN}{src}/master-0.m3u8"
            thumb = node.get("thumbnail")
            if isinstance(thumb, str) and thumb.startswith("/"):
                node["thumbnailUrl"] = f"{CDN}{thumb}"
        for v in node.values():
            _attach_hls_urls(v)
    elif isinstance(node, list):
        for v in node:
            _attach_hls_urls(v)
    return node


def build_entry(item, detail):
    entry = {
        "_id": item["_id"],
        "name": item["name"],
        "origName": detail.get("origName"),
        "ageLevel": item.get("ageLevel"),
        "dateReleased": item.get("dateReleased"),
        "categoryAlias": item.get("categoryAlias"),
        "rating": item.get("rating"),
        "duration": item.get("duration"),
        "seasonsCount": item.get("seasonsCount"),
        "countries": detail.get("countries") or ([item["countries"]] if isinstance(item.get("countries"), str) else []),
        "genres": detail.get("genreNames", []),
        "description": detail.get("shortDesc") or item.get("shortDesc") or detail.get("fullDesc"),
        "persons": detail.get("persons", []),
        "videos": _attach_hls_urls(detail.get("videos") or {}),
        "url": item.get("url"),
        "badge": item.get("badge"),
        "images": {},
    }

    for img_type, size_params in IMG_SIZES.items():
        src = None
        detail_img = detail.get(img_type) or {}
        item_img = item.get(img_type) or {}
        if detail_img.get("src"):
            src = detail_img["src"]
        elif item_img.get("src"):
            src = item_img["src"]
        if not src and img_type == "poster":
            for alt_key in ("posterBig", "posterSmall", "posterWide"):
                alt = item.get(alt_key) or {}
                if alt.get("src"):
                    src = alt["src"]
                    break
        if src:
            # Optimizer 400s on relative paths — it must get the absolute CDN URL
            abs_src = src if src.startswith("http") else f"{CDN}{src}"
            entry["images"][img_type] = {
                "src": src,
                "url": f"{SITE}/_next/image?url={quote(abs_src, safe='')}&{size_params}",
                "cdnUrl": abs_src,
                "filename": src.split("/")[-1],
            }
    return entry


def scrape_category(cat, build_id, download_images):
    print(f"\n=== {cat} ===")

    items = fetch_catalog(cat)
    print(f"  ✓ Catalog: {len(items)} unique")
    (OUT / f"catalog_{cat}.json").write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")

    print("  Fetching details...")
    details, failed_detail = {}, []
    consec_fails = 0
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        for n, (item, detail, err) in enumerate(pool.map(lambda i: fetch_detail(i, build_id), items), 1):
            if err:
                failed_detail.append(err)
                consec_fails += 1
                if consec_fails >= MAX_CONSEC_FAILS:
                    print(f"\n  ⛔ {MAX_CONSEC_FAILS} consecutive failures — looks like an IP ban (Qrator). Aborting; wait a few minutes and re-run.")
                    sys.exit(2)
            else:
                consec_fails = 0
            details[item["_id"]] = detail
            if n % 300 == 0:
                print(f"    {n}/{len(items)} ({n / max(time.time() - t0, 1):.0f}/s)", flush=True)

    detailed = [build_entry(item, details[item["_id"]]) for item in items]
    (OUT / f"catalog_{cat}_detailed.json").write_text(json.dumps(detailed, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"  ✓ Detailed: {len(detailed)}" + (f" (failed: {len(failed_detail)})" if failed_detail else ""))
    for err in failed_detail[:5]:
        print(f"    ✗ {err}")

    if download_images:
        new_img, failed_img = 0, []
        for entry in detailed:
            for itype, iinfo in entry["images"].items():
                dest = IMG / itype
                dest.mkdir(parents=True, exist_ok=True)
                fp = dest / iinfo["filename"]
                if fp.exists() and fp.stat().st_size > 0:
                    continue
                try:
                    r = session().get(iinfo["url"], timeout=60)
                    r.raise_for_status()
                    fp.write_bytes(r.content)
                    new_img += 1
                except Exception as e:
                    failed_img.append({"imgType": itype, **iinfo, "error": str(e)})
        total_img = sum(len(e["images"]) for e in detailed)
        print(f"  ✓ Images: {new_img} new / {total_img} total, failed: {len(failed_img)}")
        if failed_img:
            (OUT / f"failed_images_{cat}.json").write_text(json.dumps(failed_img, ensure_ascii=False, indent=2), encoding="utf-8")


def main():
    global PROXY
    if "--proxy" in sys.argv:
        PROXY = sys.argv[sys.argv.index("--proxy") + 1]
    download_images = "--images" in sys.argv
    films_only = "--films-only" in sys.argv
    serials_only = "--serials-only" in sys.argv
    cats = ["serials"] if serials_only else (["films"] if films_only else ["films", "serials"])

    OUT.mkdir(parents=True, exist_ok=True)
    session()
    print(f"proxy: {PROXY or 'нет'}")

    build_id = current_build_id()
    print(f"buildId: {build_id}")

    for cat in cats:
        scrape_category(cat, build_id, download_images)

    (OUT / "state.json").write_text(json.dumps({"last_run": time.strftime("%Y-%m-%dT%H:%M:%SZ"), "build_id": build_id}))
    if not download_images:
        print("\nКартинки: python3 download_tvoe_images.py (параллельно, докачает недостающее)")
    print(f"\n🎉 Done: {OUT}/")


if __name__ == "__main__":
    main()
