#!/bin/bash
# Installs jail.local and restarts fail2ban.
#
# Does not install the package. `apt-get` is not among the commands this host
# grants passwordless sudo for, and a script that hangs on a password prompt
# over ssh is worse than one that says what to run.

set -e

sudo -v 2>/dev/null || true

if ! command -v fail2ban-server > /dev/null; then
    echo "fail2ban is not installed. Install it first:" >&2
    echo "    sudo apt-get update && sudo apt-get install -y fail2ban" >&2
    exit 1
fi

CONF="$(dirname "$0")/jail.local"
echo "Installing jail.local"
sudo cp "$CONF" /etc/fail2ban/jail.local

# Ask fail2ban whether it agrees before restarting it, for the same reason the
# ssh script asks sshd: a jail that fails to parse is a jail that is not
# running, and nothing else would say so.
if ! sudo fail2ban-client -t; then
    echo "fail2ban refused the config. Not restarting." >&2
    exit 1
fi

sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban

echo "Jails now running:"
sudo fail2ban-client status
