#!/bin/bash
# Copies all systemd unit files from units/ to /etc/systemd/system/

set -e

# Refresh sudo session to avoid multiple password prompts
sudo -v

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
