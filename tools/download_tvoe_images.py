#!/usr/bin/env python3
"""Download all images from already-collected detailed catalogs (parallel, fast).

For each image: try the resized optimizer URL first, fall back to the CDN original.
Failures land in tvoe_data/failed_images.json — re-run this script to retry them.
"""
import json
import sys
import threading
import time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

DATA = Path("/Users/sasha/Documents/GitHub/kinopub-apple-client/tools/tvoe_data")
IMG = DATA / "images"
WORKERS = 3  # Qrator bans by IP after parallel bursts — keep it low
REQ_DELAY = 0.15
ATTEMPTS = 3
MAX_CONSEC_FAILS = 100

PROXY = None  # --proxy http://user:pass@host:port (RU IP required for tvoe.live; CDN works without)

_local = threading.local()


def session():
    if not hasattr(_local, "ses"):
        _local.ses = requests.Session()
        _local.ses.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
        if PROXY:
            _local.ses.proxies = {"http": PROXY, "https": PROXY}
    return _local.ses


def fetch(url, timeout, delay=REQ_DELAY):
    r = session().get(url, timeout=timeout)
    r.raise_for_status()
    if delay:
        time.sleep(delay)
    return r.content


def download_one(img_type, info, originals_only=False):
    fp = IMG / img_type / info["filename"]
    if fp.exists() and fp.stat().st_size > 0:
        return ("skip", img_type, None, info)
    urls = [] if originals_only else [info["url"]]
    if info.get("cdnUrl"):
        urls.append(info["cdnUrl"])
    delay = 0 if originals_only else REQ_DELAY  # CDN has no Qrator in front of it
    last_err = None
    for attempt in range(ATTEMPTS):
        for url in urls:
            try:
                fp.write_bytes(fetch(url, timeout=60, delay=delay))
                return ("ok", img_type, None, info)
            except Exception as e:
                last_err = e
        time.sleep(0.5 * (attempt + 1))
    return ("fail", img_type, f"{type(last_err).__name__}: {last_err}", info)


def collect_jobs():
    jobs, seen = [], set()
    for cat_file in ["catalog_films_detailed.json", "catalog_serials_detailed.json"]:
        fp = DATA / cat_file
        if not fp.exists():
            continue
        for entry in json.loads(fp.read_text(encoding="utf-8")):
            for img_type, info in entry.get("images", {}).items():
                key = (img_type, info["filename"])
                if key not in seen:
                    seen.add(key)
                    jobs.append((img_type, info))
    return jobs


def main():
    global PROXY
    if "--proxy" in sys.argv:
        PROXY = sys.argv[sys.argv.index("--proxy") + 1]
    originals_only = "--cdn-originals" in sys.argv  # full-size from CDN; works while tvoe.live is banned, but ~5x heavier
    for sub in ["poster", "cover", "logo"]:
        (IMG / sub).mkdir(parents=True, exist_ok=True)
    jobs = collect_jobs()
    print(f"Всего картинок: {len(jobs)}" + (" (CDN originals)" if originals_only else ""))
    ok = skip = 0
    failed = []
    t0 = time.time()

    workers = 8 if originals_only else WORKERS
    consec_fails = 0
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(download_one, t, i, originals_only) for t, i in jobs]
        for n, fut in enumerate(as_completed(futures), 1):
            status, img_type, err, info = fut.result()
            if status == "ok":
                ok += 1
                consec_fails = 0
            elif status == "skip":
                skip += 1
                consec_fails = 0
            else:
                failed.append({"imgType": img_type, **info, "error": err})
                consec_fails += 1
                if consec_fails >= MAX_CONSEC_FAILS:
                    print(f"\n⛔ {MAX_CONSEC_FAILS} consecutive failures — looks like an IP ban. Wait a few minutes and re-run; existing files are kept.")
                    break
            if n % 500 == 0:
                rate = n / max(time.time() - t0, 1)
                print(f"  {n}/{len(jobs)} ok={ok} skip={skip} fail={len(failed)} ({rate:.0f}/s)", flush=True)

    print(f"\nOK: {ok}  Skip: {skip}  Fail: {len(failed)}  ({time.time()-t0:.0f}s)")
    fail_fp = DATA / "failed_images.json"
    if failed:
        fail_fp.write_text(json.dumps(failed, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Ошибки → {fail_fp} (повторный запуск докачает)")
    elif fail_fp.exists():
        fail_fp.unlink()
    print(f"→ {IMG}/")


if __name__ == "__main__":
    main()
