#!/bin/bash
# Copies all systemd unit files from units/ to /etc/systemd/system/

set -e

# Refresh the sudo timestamp when the box allows it. This host grants
# passwordless sudo per command but not bare `sudo -v`, and every command
# below is one of the permitted ones, so a failure here must not stop the
# script -- otherwise it cannot be run over ssh without a terminal.
sudo -v 2>/dev/null || true

UNIT_DIR="$(dirname "$0")/units"
TARGET_DIR="/etc/systemd/system/"

for unit in "$UNIT_DIR"/*; do
    if [[ -f "$unit" ]]; then
        echo "Copying $unit to $TARGET_DIR"
        sudo cp "$unit" "$TARGET_DIR"
    fi
done

echo "All unit files copied."

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload
