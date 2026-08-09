#!/usr/bin/env python3
"""
One-off migration: reorganize existing flat-layout backups in
s3://jordaneldredge-backup-bucket/<prefix>/ into the tiered GFS layout
<prefix>/{daily,weekly,monthly,yearly}/.

Retention (relative to today):
  daily   -- last 7 days
  weekly  -- one per week for last 4 weeks
  monthly -- one per month for last 12 months
  yearly  -- one per year, forever

Each surviving date is placed in the longest-retention tier it qualifies
for; everything else is deleted.

Shells out to the `aws` CLI so it has no Python deps beyond the stdlib.
Default is DRY RUN. Pass --execute to perform copies/deletes.
"""

import argparse
import json
import re
import subprocess
from collections import defaultdict
from datetime import date, timedelta

BUCKET = "jordaneldredge-backup-bucket"

# (source prefix, filename regex capturing YYYY-MM-DD).
# Multiple entries with the same prefix are OK -- each pattern is treated
# as an independent stream with its own GFS survivors.
PREFIXES = [
    ("skins_database/",
     re.compile(r"^skins_db_backup_archive_(\d{4}-\d{2}-\d{2})\.sqlite3(?:\.gz)?$")),
    ("jordaneldredge.com/",
     re.compile(r"^db_backup_archive_(\d{4}-\d{2}-\d{2})\.sqlite3(?:\.gz)?$")),
    ("capt.dev/",
     re.compile(r"^db_backup_archive_(\d{4}-\d{2}-\d{2})\.sqlite3(?:\.gz)?$")),
    # nicolasaliaga.com -- orphaned prefix (systemd unit removed May 2026).
    # Two filename patterns coexist here; handle each as its own stream so
    # zips and DB dumps get independent yearly picks.
    ("nicolasaliaga.com/",
     re.compile(r"^(\d{4}-\d{2}-\d{2})\.zip$")),
    ("nicolasaliaga.com/",
     re.compile(r"^db_(\d{4}-\d{2}-\d{2})\.sql$")),
]

TIERS = ["yearly", "monthly", "weekly", "daily"]


def aws(*args, capture=True):
    """Run `aws <args>`, return decoded JSON if capture, else the raw result."""
    cmd = ["aws"] + list(args)
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    if capture and result.stdout.strip():
        return json.loads(result.stdout)
    return result


def list_objects(prefix):
    """Yield object dicts under prefix (paginated)."""
    token = None
    while True:
        args = ["s3api", "list-objects-v2",
                "--bucket", BUCKET, "--prefix", prefix,
                "--output", "json"]
        if token:
            args += ["--starting-token", token]
        data = aws(*args) or {}
        for obj in data.get("Contents", []) or []:
            yield obj
        token = data.get("NextToken")
        if not token:
            return


def compute_survivors(by_date, today):
    """by_date: {date: key}. Returns {key: tier}."""
    survivors = {}
    by_year = defaultdict(list)
    by_month = defaultdict(list)
    by_iso_week = defaultdict(list)
    for d in by_date:
        by_year[d.year].append(d)
        by_month[(d.year, d.month)].append(d)
        iso = d.isocalendar()
        by_iso_week[(iso[0], iso[1])].append(d)

    def claim(candidates, tier):
        for d in sorted(candidates):
            k = by_date[d]
            if k not in survivors:
                survivors[k] = tier
                return

    for year, dates in by_year.items():
        claim(dates, "yearly")

    ym = today.replace(day=1)
    for _ in range(12):
        claim(by_month.get((ym.year, ym.month), []), "monthly")
        ym = (ym - timedelta(days=1)).replace(day=1)

    ref = today
    for _ in range(4):
        iso = ref.isocalendar()
        claim(by_iso_week.get((iso[0], iso[1]), []), "weekly")
        ref -= timedelta(days=7)

    for i in range(7):
        d = today - timedelta(days=i)
        k = by_date.get(d)
        if k and k not in survivors:
            survivors[k] = "daily"

    # Invariant: always keep the most recent snapshot, even if it falls outside
    # every tier window (e.g. an orphaned prefix where writes stopped years
    # ago). Bucketed as yearly since that never expires.
    if by_date:
        newest_key = by_date[max(by_date)]
        if newest_key not in survivors:
            survivors[newest_key] = "yearly"

    return survivors


def migrate_prefix(prefix, filename_re, today, execute):
    print(f"\n=== {prefix} ===")

    by_date = {}
    unrecognized = []
    duplicate_dates = []

    for obj in list_objects(prefix):
        rel = obj["Key"][len(prefix):]
        if "/" in rel:
            continue  # already in a tier subprefix
        m = filename_re.match(rel)
        if not m:
            unrecognized.append(obj["Key"])
            continue
        d = date.fromisoformat(m.group(1))
        if d in by_date:
            existing = by_date[d]
            # Prefer .gz over uncompressed if both exist
            if obj["Key"].endswith(".gz") and not existing.endswith(".gz"):
                duplicate_dates.append(existing)
                by_date[d] = obj["Key"]
            else:
                duplicate_dates.append(obj["Key"])
        else:
            by_date[d] = obj["Key"]

    if unrecognized:
        print(f"  unrecognized (will be left alone): {len(unrecognized)}")
        for k in unrecognized[:5]:
            print(f"    {k}")
        if len(unrecognized) > 5:
            print(f"    ... and {len(unrecognized) - 5} more")

    if not by_date:
        print("  (no flat-layout files matched)")
        return

    print(f"  found {len(by_date)} flat-layout files "
          f"({len(duplicate_dates)} duplicate-date copies)")

    survivors = compute_survivors(by_date, today)
    losers = [k for k in by_date.values() if k not in survivors] + duplicate_dates

    for tier in TIERS:
        tier_keys = sorted(k for k, t in survivors.items() if t == tier)
        print(f"  {tier}: {len(tier_keys)}")
        for key in tier_keys:
            filename = key.rsplit("/", 1)[-1]
            new_key = f"{prefix}{tier}/{filename}"
            print(f"    KEEP  {key}")
            print(f"         -> {new_key}")
    print(f"  DELETE: {len(losers)} objects to be removed from the flat layout")

    if not execute:
        return

    for old_key, tier in survivors.items():
        filename = old_key.rsplit("/", 1)[-1]
        new_key = f"{prefix}{tier}/{filename}"
        aws("s3api", "copy-object",
            "--bucket", BUCKET,
            "--copy-source", f"{BUCKET}/{old_key}",
            "--key", new_key,
            "--metadata-directive", "COPY",
            capture=False)
        aws("s3api", "delete-object",
            "--bucket", BUCKET,
            "--key", old_key,
            capture=False)
        print(f"    moved {old_key} -> {new_key}")

    # delete-objects accepts up to 1000 per call
    for i in range(0, len(losers), 1000):
        batch = losers[i:i + 1000]
        payload = json.dumps({"Objects": [{"Key": k} for k in batch],
                              "Quiet": True})
        aws("s3api", "delete-objects",
            "--bucket", BUCKET,
            "--delete", payload,
            capture=False)
        print(f"    deleted batch of {len(batch)}")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--execute", action="store_true",
                        help="Actually copy/delete. Default is dry-run.")
    parser.add_argument("--today",
                        help="Override reference date YYYY-MM-DD (for testing).")
    parser.add_argument("--prefix",
                        help="Only migrate this source prefix, e.g. skins_database/")
    args = parser.parse_args()

    today = date.fromisoformat(args.today) if args.today else date.today()
    print(f"Reference date: {today}")
    print(f"Mode: {'EXECUTE' if args.execute else 'DRY RUN'}")

    for prefix, filename_re in PREFIXES:
        if args.prefix and prefix != args.prefix:
            continue
        migrate_prefix(prefix, filename_re, today, args.execute)

    if not args.execute:
        print("\n(dry run -- pass --execute to perform actions)")


if __name__ == "__main__":
    main()
