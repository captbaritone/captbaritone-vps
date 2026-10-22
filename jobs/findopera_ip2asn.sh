#!/bin/bash
#
# FindOpera: rebuild ip2asn.bin from iptoasn.com's current table.
#
# The app looks up each analytics event's address in this file for its
# network owner and country, and keeps those instead of the address. It is
# also how a visit from a datacenter gets marked as a bot. Networks are
# bought, sold and renumbered, so a table left alone slowly puts addresses in
# the wrong network; nothing fails when it goes stale, which is why this is a
# timer and not something to remember.
#
# The running app reads the file once, at boot, so a new table takes effect
# at the next deploy or restart. For a monthly refresh that is soon enough,
# and it keeps a timer from restarting the site.

set -euo pipefail

app=~/projects/find-opera
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

download=$workdir/ip2asn-v4.tsv.gz
curl -sSfL --retry 3 -o "$download" https://iptoasn.com/data/ip2asn-v4.tsv.gz

# The whole table is about 7MB compressed. Something far smaller is an error
# page or a truncated mirror, and a table built from it would quietly answer
# null for most of the internet.
size=$(stat -c %s "$download")
if [ "$size" -lt 3000000 ]; then
    echo "findopera ip2asn: download is only $size bytes, keeping the old table" >&2
    exit 1
fi

# The build reads its own output back before renaming it over the old file,
# so a bad download or a failed build leaves the current table in place.
cd "$app"
node scripts/ip2asn.ts "$download" ip2asn.bin
