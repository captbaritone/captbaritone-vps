#!/bin/zsh
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

# Enable all .service units
for unit in "$UNIT_DIR"/*.service; do
    unit_name="$(basename "$unit")"
    echo "Enabling $unit_name..."
    sudo systemctl enable --now "$unit_name"
done

# Enable all .timer units
for timer in "$UNIT_DIR"/*.timer; do
    timer_name="$(basename "$timer")"
    echo "Enabling $timer_name..."
    sudo systemctl enable --now "$timer_name"
done
