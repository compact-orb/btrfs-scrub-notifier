# btrfs-scrub-notifier

[![CodeFactor](https://www.codefactor.io/repository/github/compact-orb/btrfs-scrub-notifier/badge)](https://www.codefactor.io/repository/github/compact-orb/btrfs-scrub-notifier)

A tool to automate regular Btrfs scrubs and receive immediate desktop notifications if errors are found.

This script interfaces with D-Bus to send a `notify-send` alert to the configured user, even when the scrub is triggered by a background `root` system service.

If your drive is dying or experiencing bit flips, you shouldn't have to check a log file to know. The alert pops up directly on your desktop.

## Installation

A Makefile is provided for quick installation.

```bash
sudo make install
```

This will install:

- `btrfs-scrub-notifier.sh` to `/usr/local/bin`
- `btrfs-scrub-notifier.conf` to `/etc`
- systemd timer & service units to `/etc/systemd/system`

Remember to reload the systemd daemon after installation:

```bash
sudo systemctl daemon-reload
```

## Configuration

Edit `/etc/btrfs-scrub-notifier.conf` to configure the target user for desktop notifications and the directory where detailed error reports should be saved.

```conf
TARGET_USER="user" # Change this to your username
LOG_DIR="/home/user/example"
```

*(Ensure `LOG_DIR` is accessible and a place you commonly monitor, in case you miss the notification)*

## Usage

The systemd units are templated. This means you enable them individually for specific mount points.
The systemd template parameter `%f` represents an escaped file path. Systemd will unescape escaped hyphens.

To enable the weekly scrub for the root filesystem (`/`):

```bash
sudo systemctl enable --now btrfs-scrub-notifier@-.timer
# NOTE: '-' represents the root directory in systemd-escaped paths.
```

To enable for a `/mnt/data` filesystem:

```bash
# systemd-escape -p /mnt/data outputs 'mnt-data'
sudo systemctl enable --now btrfs-scrub-notifier@mnt-data.timer
```

To run a manual test immediately:

```bash
sudo systemctl start btrfs-scrub-notifier@-.service
```

## How It Works

1. The systemd timer triggers the service.
2. The service executes `btrfs-scrub-notifier.sh <mountpoint>` as `root`.
3. The script runs `btrfs scrub start -Bd` in the foreground and waits.
4. It parses the final output and exit status for signs of failure.
5. If errors exist, it writes the full scrub report to `LOG_DIR`.
6. It then finds the specified user's `D-Bus` session via `/run/user/<uid>/bus` and issues `notify-send` as that user.

## Uninstallation

```bash
sudo make uninstall
```
