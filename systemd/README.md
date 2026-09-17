# Captbaritone VPS

Systemd units and other configuration files for setting up my VPS which hosts various services.


## Services

To enable a service/start:

```bash
sudo systemctl enable --now <service-name>
```

To enable a timer/start:

```bash
sudo systemctl enable --now <timer-name>
```

To view logs for a service:

```bash
sudo journalctl -u <service-name> -f

## SSH and fail2ban

`ssh/` raises how many unauthenticated connections sshd will hold, and caps
them per source. `fail2ban/` bans the addresses that keep trying.

Both exist for the same measured problem. Over four days this host took 84,115
ssh connection attempts from 1,341 addresses; sshd dropped more than a thousand
connections for exceeding `MaxStartups`, and three of those were GitHub Actions
trying to deploy. A refused deploy fails after the build has shipped, which
leaves new code beside an old process until somebody re-runs it.

They are not alternatives. 822 of those addresses tried more than five times,
and 94% of all attempts came after a given address's fifth -- so a jail removes
most of the load, and the raised limits stop what is left from refusing a
connection that matters. A ban list only knows about behaviour it has already
seen.

```bash
sudo apt-get update && sudo apt-get install -y fail2ban   # once
./fail2ban/update.sh
./ssh/update.sh
```

`ssh/update.sh` validates with `sshd -t` before reloading and puts the previous
file back if the config is refused, because a bad sshd config plus a reload is
how a remote host stops accepting connections. It reloads rather than restarts,
so the session running it survives.

Check what is banned:

```bash
sudo fail2ban-client status sshd
```
