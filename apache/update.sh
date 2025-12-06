#!/bin/bash
# Copies all apache sites from sites-avaliable/ to /etc/apache2/sites-available/

set -e

# Refresh sudo session to avoid multiple password prompts
sudo -v

UNIT_DIR="$(dirname "$0")/sites-available"
TARGET_DIR="/etc/apache2/sites-available/"

for unit in "$UNIT_DIR"/*; do
    if [[ -f "$unit" ]]; then
        echo "Copying $unit to $TARGET_DIR"
        sudo cp "$unit" "$TARGET_DIR"
    fi
done

echo "All sites files copied."

echo "Reloading Apache..."
sudo systemctl reload apache2
