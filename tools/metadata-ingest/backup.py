#!/usr/bin/env python3
"""Back the record up in two tiers, because two kinds of data live in it.

    python3 backup.py            # both tiers
    python3 backup.py --tier git # only the small, irreplaceable part

**Tier 1 — committed.** The identity map, `fetch_log`, provider health and the
schema version, as gzipped JSON Lines. Small, and the expensive part: rebuilding
`title_external_id` cost 22 690 API calls once, and losing it is what made a
schema change turn into a re-crawl. ~300 KB gzipped for 46 000 pairs.

**Tier 2 — not committed.** `sqlite3 .dump`, hundreds of megabytes. Kept under
`data/`, which is gitignored, and copied somewhere else by whatever the machine
already uses for backups.

Splitting them this way is the point: git stays a place you can clone quickly,
and still carries everything that cannot be regenerated for free.
"""

from __future__ import annotations

import argparse
import gzip
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import DEFAULT_DB, connect, now  # noqa: E402

# Tables whose rows carry no local key and restore verbatim.
FLAT_TIER = {
    "fetch_log": "SELECT * FROM fetch_log ORDER BY source, endpoint, key",
    "provider_health": "SELECT * FROM provider_health ORDER BY provider",
    "schema_version": "SELECT * FROM schema_version ORDER BY version",
}


def dump_identity_clusters(conn, path: Path) -> int:
    """The identity map, exported as **id-to-id clusters**, not as rows.

    `title.id` is a local autoincrement: it is reassigned on every rebuild, so a
    dump containing it only restores into the database it came from — useless
    for the one case that matters, restoring after a rebuild. What is actually
    durable is the *pairing*: kinopub 7 ↔ imdb tt0111161 ↔ tmdb movie/1396. A
    cluster survives any renumbering because it never mentions our ids.
    """
    clusters: dict[int, list] = {}
    for row in conn.execute(
        "SELECT title_id, namespace, value, confidence, method FROM title_external_id"
        " ORDER BY title_id, namespace"
    ):
        clusters.setdefault(row["title_id"], []).append(
            [row["namespace"], row["value"], row["confidence"], row["method"]])
    with gzip.open(path, "wt", encoding="utf-8") as stream:
        for ids in clusters.values():
            stream.write(json.dumps({"ids": ids}, ensure_ascii=False,
                                    separators=(",", ":")) + "\n")
    return len(clusters)


def restore_identity_clusters(conn, path: Path) -> tuple[int, int, int]:
    """Re-link a rebuilt record. Returns (clusters, links added, unmatched)."""
    from common import find_by_external, link_external

    total = added = unmatched = 0
    with gzip.open(path, "rt", encoding="utf-8") as stream:
        for line in stream:
            total += 1
            ids = json.loads(line)["ids"]
            title_id = None
            for namespace, value, _, _ in ids:
                title_id = find_by_external(conn, namespace, value)
                if title_id:
                    break
            if not title_id:
                unmatched += 1
                continue
            for namespace, value, confidence, method in ids:
                before = find_by_external(conn, namespace, value)
                link_external(conn, title_id, namespace, value, method, confidence)
                if before is None:
                    added += 1
    conn.commit()
    return total, added, unmatched


def dump_git_tier(conn, out_dir: Path) -> list[tuple[str, int, int]]:
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    clusters = dump_identity_clusters(conn, out_dir / "identity.jsonl.gz")
    written.append(("identity (clusters)", clusters,
                    (out_dir / "identity.jsonl.gz").stat().st_size))
    for table, query in FLAT_TIER.items():
        try:
            rows = conn.execute(query).fetchall()
        except Exception:
            continue
        path = out_dir / f"{table}.jsonl.gz"
        with gzip.open(path, "wt", encoding="utf-8") as stream:
            for row in rows:
                stream.write(json.dumps(dict(row), ensure_ascii=False,
                                        separators=(",", ":")) + "\n")
        written.append((table, len(rows), path.stat().st_size))
    (out_dir / "MANIFEST.json").write_text(json.dumps({
        "written_at": now(),
        "tables": {table: count for table, count, _ in written},
    }, indent=2) + "\n")
    return written


def restore_git_tier(conn, out_dir: Path) -> dict[str, int]:
    """Reload the committed tier into a record that has lost it."""
    restored = {}
    identity = out_dir / "identity.jsonl.gz"
    if identity.exists():
        total, added, unmatched = restore_identity_clusters(conn, identity)
        print(f"  identity clusters {total:>8,}  links added {added:,}  unmatched {unmatched:,}")
    for table in FLAT_TIER:
        path = out_dir / f"{table}.jsonl.gz"
        if not path.exists():
            continue
        count = 0
        with gzip.open(path, "rt", encoding="utf-8") as stream:
            for line in stream:
                row = json.loads(line)
                columns = ",".join(row)
                marks = ",".join("?" * len(row))
                conn.execute(f"INSERT OR IGNORE INTO {table}({columns}) VALUES ({marks})",
                             tuple(row.values()))
                count += 1
        restored[table] = count
    conn.commit()
    return restored


def dump_full(db: Path, out_dir: Path, stamp: str) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / f"record-{stamp}.sql.gz"
    with gzip.open(target, "wb") as stream:
        proc = subprocess.run(["sqlite3", str(db), ".dump"], stdout=subprocess.PIPE, check=True)
        stream.write(proc.stdout)
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--tier", choices=("git", "full", "both"), default="both")
    parser.add_argument("--restore", action="store_true", help="reload the committed tier")
    args = parser.parse_args()

    here = Path(__file__).resolve().parent
    git_dir = here / "backup"
    conn = connect(args.db)

    if args.restore:
        for table, count in restore_git_tier(conn, git_dir).items():
            print(f"  restored {table:<20} {count:>8,}")
        return 0

    if args.tier in ("git", "both"):
        total = 0
        for table, count, size in dump_git_tier(conn, git_dir):
            print(f"  {table:<20} {count:>8,} rows  {size / 1024:>7.0f} KB")
            total += size
        print(f"  {'committed tier':<20} {'':>8}       {total / 1024:>7.0f} KB total")

    if args.tier in ("full", "both"):
        stamp = now()[:10].replace("-", "")
        target = dump_full(args.db, args.db.parent, stamp)
        print(f"  full dump (not committed)       {target.stat().st_size / 1e6:>7.0f} MB"
              f"  {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
