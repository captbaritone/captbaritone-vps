#!/bin/bash
#
# FindOpera: daily SQLite backup to S3, on the same GFS tiers as the others.
#
# The catalog is the only copy of 11,125 recordings, 86,419 portrayals and the
# whole append-only edit history. Versioning protects a record from a bad edit;
# it does nothing about a lost disk, and until this existed nothing did.

set -euo pipefail

source "$(dirname "$0")/tier.sh"

today=$(date +"%Y-%m-%d")
tier=$(tier_for_today)
db=~/projects/find-opera/data.db
backupdir=~/captbaritone-vps/backup/findopera-$today
snapshot=$backupdir/data.sqlite3
archive=$snapshot.gz

# Leave nothing behind on any exit, including a failure partway through. The
# snapshot is ~180MB and this runs daily; a few failed runs quietly filling the
# disk would be its own outage.
cleanup() { rm -rf "$backupdir"; }
trap cleanup EXIT

mkdir -p "$backupdir"

# `.backup`, not `cp`. The app runs this database in WAL mode and checkpoints
# every 30 seconds, so copying the file out from under a live writer can catch
# it mid-transaction. `.backup` takes a consistent snapshot of a database that
# is still being written to, which is the entire reason it exists.
sqlite3 "$db" ".backup '$snapshot'"

# A backup nobody has checked is a guess. This is the only moment the snapshot
# is cheap to verify -- on the machine that made it, before it is compressed
# and shipped to a bucket this host is not even allowed to read back.
check=$(sqlite3 "$snapshot" "PRAGMA integrity_check;")
if [ "$check" != "ok" ]; then
    echo "findopera backup: integrity check failed: $check" >&2
    exit 1
fi

gzip -c "$snapshot" > "$archive"
rm "$snapshot"

/usr/local/bin/aws s3 --profile=backup-agent \
    mv "$archive" \
    "s3://jordaneldredge-backup-bucket/findopera.com/$tier/findopera_db_backup_archive_$today.sqlite3.gz"
