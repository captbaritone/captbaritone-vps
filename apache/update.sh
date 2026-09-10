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

# Shared snippets (log formats and the like). Enabling is idempotent.
CONF_DIR="$(dirname "$0")/conf-available"
if [[ -d "$CONF_DIR" ]]; then
    for conf_file in "$CONF_DIR"/*.conf; do
        [[ -f "$conf_file" ]] || continue
        echo "Copying $conf_file to /etc/apache2/conf-available/"
        sudo cp "$conf_file" /etc/apache2/conf-available/
        sudo a2enconf "$(basename "$conf_file" .conf)" > /dev/null
    done
    echo "All conf files copied and enabled."
fi

# Never reload a config that will not parse: this Apache fronts every site on
# the box, so a bad file takes all of them down rather than one.
echo "Checking configuration..."
sudo apache2ctl configtest

echo "Reloading Apache..."
sudo systemctl reload apache2
