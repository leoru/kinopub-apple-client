#!/usr/bin/env python3
"""Grow the identity map, in place, with no database and no dumps.

    python3 resolve_identity.py --limit 500

Reads `backup/identity.jsonl.gz`, finds clusters that have an IMDb id but no
TMDB one, resolves that many through the worker proxy, and writes the file back.

**Manual only, on purpose.** This was briefly a nightly job and that was wrong:
pre-resolving 45 000 titles nobody has opened is the sweep habit again, wearing a
schedule. Identity is resolved *on demand*, by the API, when a client asks about
a title — see `/v1/title/by/kinopub/{id}` in the worker, which resolves from the
hints the client sends and stores the answer.

What is left here is a hand tool: run it against a batch you actually want warm
(a top list, a collection) rather than against the catalogue.
"""

from __future__ import annotations

import argparse
import gzip
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_MAP = HERE / "backup" / "identity.jsonl.gz"
PROXY = "https://kinopub-tmdb-proxy.traneblow1nd.workers.dev"
AGENT = "kinopub-metadata-ingest/1.0 (+tools/metadata-ingest)"


def load(path: Path) -> list[dict]:
    with gzip.open(path, "rt", encoding="utf-8") as stream:
        return [json.loads(line) for line in stream if line.strip()]


def save(path: Path, clusters: list[dict]) -> None:
    tmp = path.with_suffix(".tmp")
    with gzip.open(tmp, "wt", encoding="utf-8") as stream:
        for cluster in clusters:
            stream.write(json.dumps(cluster, ensure_ascii=False,
                                    separators=(",", ":")) + "\n")
    tmp.replace(path)


def namespaces(cluster: dict) -> dict[str, str]:
    return {entry[0]: entry[1] for entry in cluster["ids"]}


def find(imdb: str, timeout=20):
    """(status, payload). A network error is not an answer and returns None."""
    url = f"{PROXY}/3/find/{imdb}?" + urllib.parse.urlencode(
        {"external_source": "imdb_id"})
    request = urllib.request.Request(url, headers={
        "Accept": "application/json", "User-Agent": AGENT})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        return error.code, None
    except Exception:
        return None, None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--map", type=Path, default=DEFAULT_MAP)
    parser.add_argument("--limit", type=int, default=500)
    parser.add_argument("--rps", type=float, default=4.0)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not args.map.exists():
        print(f"no identity map at {args.map}")
        return 1

    clusters = load(args.map)
    pending = [c for c in clusters
               if "imdb" in namespaces(c) and "tmdb" not in namespaces(c)
               and not c.get("tmdb_miss")]
    total_resolved = sum(1 for c in clusters if "tmdb" in namespaces(c))
    print(f"{len(clusters):,} clusters · {total_resolved:,} already resolved · "
          f"{len(pending):,} pending")
    if not pending:
        print("nothing to do")
        return 0

    interval = 1.0 / args.rps if args.rps else 0.0
    resolved = missed = failed = 0

    for cluster in pending[:args.limit]:
        imdb = namespaces(cluster)["imdb"]
        status, payload = find(imdb)
        if payload is None:
            failed += 1
            if status is None:
                continue
            # A 4xx/5xx from the proxy is about us, not about this title — stop
            # rather than mark hundreds of titles as missing.
            print(f"stopping: proxy returned {status}")
            break
        for media_type in ("movie", "tv"):
            results = payload.get(f"{media_type}_results") or []
            if results:
                cluster["ids"].append(["tmdb", f"{media_type}/{results[0]['id']}",
                                       1.0, "find:imdb"])
                resolved += 1
                break
        else:
            # A real "no such title" — remember it so tomorrow's run skips it.
            cluster["tmdb_miss"] = True
            missed += 1
        if interval:
            time.sleep(interval)

    print(f"resolved={resolved:,}  no-match={missed:,}  failed={failed:,}")
    if args.dry_run:
        print("dry run, not writing")
        return 0
    if resolved or missed:
        save(args.map, clusters)
        print(f"wrote {args.map} · {args.map.stat().st_size / 1024:.0f} KB · "
              f"{total_resolved + resolved:,} resolved in total")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
