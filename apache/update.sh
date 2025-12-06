#!/bin/bash
# Copies all apache sites from sites-avaliable/ to /etc/apache2/sites-avaliable/

set -e

# Refresh sudo session to avoid multiple password prompts
sudo -v

SITES_DIR="$(dirname "$0")/sites-avaliable"
TARGET_DIR="/etc/apache2/sites-available/"

for site_file in "$SITES_DIR"/*; do
    if [[ -f "$site_file" ]]; then
        echo "Copying $site_file to $TARGET_DIR"
        sudo cp "$site_file" "$TARGET_DIR"
    fi
done

echo "All sites files copied."

echo "Reloading Apache..."
sudo systemctl reload apache2
