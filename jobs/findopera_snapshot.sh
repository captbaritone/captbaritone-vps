#!/bin/bash
#
# FindOpera: build the weekly catalog snapshot, findopera.db.zip.
#
# https://findopera.com/data offers it as a download. The app serves it from
# findopera.db.zip in its own directory, beside data.db, through the route in
# app/findopera.db.zip/route.ts.
#
# Built by the public script, from an empty file, against the public API, with
# no token. That is what /data promises: the snapshot holds nothing the API
# does not give anybody. Starting from scratch every week, rather than
# catching up from last week's file, checks that promise every week, and means
# a mistake in one snapshot cannot carry into the next.
#
# Anonymous, the script is held to 60 requests a minute, so a build takes
# about eleven minutes. Almost all of that is waiting; each request costs the
# app a few milliseconds.

set -euo pipefail

app=~/projects/find-opera

# Built in the home directory, on the same filesystem as the app, so the final
# rename replaces the file in one step. A download in progress keeps reading
# the file it opened.
workdir=$(mktemp -d ~/.findopera-snapshot.XXXXXX)
trap 'rm -rf "$workdir"' EXIT

cd "$workdir"
python3 "$app/public/examples/sync_catalog.py" findopera.db

# VACUUM drops the free pages left by rows the build replaced, which takes
# about 15% off the zip. The checks refuse to publish a damaged file, or one
# with an empty table: every table in the catalog has rows, so an empty one
# means the build went wrong, and last week's file stays up.
python3 - <<'PY'
import sqlite3
db = sqlite3.connect("findopera.db")
db.execute("VACUUM")
assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
tables = [r[0] for r in db.execute(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name != 'sync_state'")]
for table in tables:
    n = db.execute(f'SELECT count(*) FROM "{table}"').fetchone()[0]
    print(f"{table}: {n}")
    assert n > 0, f"{table} is empty"
PY

zip -9 -q findopera.db.zip findopera.db
chmod 644 findopera.db.zip
mv findopera.db.zip "$app/findopera.db.zip"
echo "findopera snapshot: $(stat -c %s "$app/findopera.db.zip") bytes"
