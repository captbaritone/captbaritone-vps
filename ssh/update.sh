#!/bin/bash
# Installs the sshd drop-ins from sshd_config.d/ and reloads sshd.
#
# The validation below is not ceremony. A refused sshd config plus a reload is
# how a remote host stops accepting connections, and the way back in is the
# provider's console. So: copy, ask sshd whether the whole config still parses,
# put it back the way it was if not, and only then reload.
#
# Reload rather than restart, so connections already open -- including the one
# running this -- survive being wrong.

set -e

# Refresh the sudo timestamp when the box allows it. This host grants
# passwordless sudo per command but not bare `sudo -v`, so a failure here must
# not stop the script.
sudo -v 2>/dev/null || true

DROPIN_DIR="$(dirname "$0")/sshd_config.d"
TARGET_DIR="/etc/ssh/sshd_config.d"

if ! grep -q "^Include ${TARGET_DIR}/\*.conf" /etc/ssh/sshd_config; then
    echo "sshd_config does not Include ${TARGET_DIR}/*.conf; a drop-in here would do nothing." >&2
    exit 1
fi

for conf in "$DROPIN_DIR"/*.conf; do
    [[ -f "$conf" ]] || continue
    name="$(basename "$conf")"
    target="$TARGET_DIR/$name"

    # Keep whatever is there now, so a refused config can be undone.
    backup=""
    if sudo test -f "$target"; then
        backup="$(mktemp)"
        sudo cat "$target" > "$backup"
    fi

    echo "Installing $name"
    sudo cp "$conf" "$target"

    if ! sudo sshd -t; then
        echo "sshd refused the config. Reverting $name and leaving sshd alone." >&2
        if [[ -n "$backup" ]]; then
            sudo cp "$backup" "$target"
        else
            sudo rm -f "$target"
        fi
        exit 1
    fi
done

echo "Config parses. Reloading sshd..."
# The unit is `ssh` on Debian and Ubuntu and `sshd` elsewhere.
sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd

echo "Effective limits now:"
sudo sshd -T | grep -iE "^maxstartups|^persourcemaxstartups"
