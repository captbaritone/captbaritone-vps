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