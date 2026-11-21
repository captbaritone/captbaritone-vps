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

# Units that have an [Install] section but must not start at boot.
#
# fachme.service: the Flask dev server FachMe ran under before it moved to the
# Docker compose stack in ~/projects/fachme, whose containers restart
# themselves. Enabled, it would come up at boot as a second copy on
# 0.0.0.0:5000.
KEEP_DISABLED=(fachme.service)

# Enable every other unit that has an [Install] section, so it comes back
# after a reboot. Copying a unit and starting it by hand does not do that:
# find-opera.service ran that way for a month, and would have stayed down
# after the first reboot. Units without [Install] are started by a timer or
# another unit, and cannot be enabled themselves.
#
# Enable only, not --now: starting a stopped service is a deploy's decision.
for unit in "$UNIT_DIR"/*; do
    name="$(basename "$unit")"
    [[ -f "$unit" ]] && grep -q '^\[Install\]' "$unit" || continue
    if [[ " ${KEEP_DISABLED[*]} " == *" $name "* ]]; then
        echo "Leaving $name disabled"
        continue
    fi
    if [[ "$(systemctl is-enabled "$name" 2>/dev/null)" != enabled ]]; then
        echo "Enabling $name"
        sudo systemctl enable "$name"
    fi
    if ! systemctl is-active --quiet "$name"; then
        echo "  note: $name is enabled but not running; start it with: sudo systemctl start $name"
    fi
done

echo "All units with an [Install] section are enabled."
