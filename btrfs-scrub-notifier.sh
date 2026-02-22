#!/usr/bin/env bash

# btrfs-scrub-notifier
# A tool to run Btrfs scrub and notify a user of any errors.

set -euo pipefail

CONFIG_FILE="/etc/btrfs-scrub-notifier.conf"

# Default configuration
TARGET_USER=""
LOG_DIR=""

# Load configuration if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

TEST_MODE=0
MOUNT_POINT=""

# Basic argument parsing
for arg in "$@"; do
    case $arg in
        --test|-t)
            TEST_MODE=1
            shift
            ;;
        *)
            MOUNT_POINT="$1"
            shift
            ;;
    esac
done

if [[ -z "$MOUNT_POINT" ]]; then
    echo "Usage: $0 [--test] <mount-point>"
    exit 1
fi

if [[ -z "$TARGET_USER" || -z "$LOG_DIR" ]]; then
    echo "Error: TARGET_USER and LOG_DIR must be set in $CONFIG_FILE"
    exit 1
fi

# Ensure log directory exists
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir --parents "$LOG_DIR"
    # Inherit ownership from its parent directory, in case it was created in a user's home dir
    PARENT_DIR=$(dirname "$LOG_DIR")
    PARENT_OWNER=$(stat --format='%U:%G' "$PARENT_DIR" 2>/dev/null || echo "")
    if [[ -n "$PARENT_OWNER" ]]; then
        chown "$PARENT_OWNER" "$LOG_DIR"
    fi
fi

# Run the scrub in the foreground. Ignore the exit code here as we want to 
# capture the output and parse it for robust error handling.
if [[ "$TEST_MODE" -eq 1 ]]; then
    echo "Running in TEST MODE. Simulating a failing btrfs scrub on $MOUNT_POINT."
    SCRUB_OUTPUT="UUID:             00000000-0000-0000-0000-000000000000
Scrub started:    Sun Feb 22 17:45:00 2026
Status:           finished
Duration:         0:00:03
Total to scrub:   1.00GiB
Rate:             341.33MiB/s
Error summary:    verify=1 csum=1
  Corrected:      0
  Uncorrectable:  2
  Unverified:     0"
    SCRUB_EXIT_CODE=3
else
    set +e
    SCRUB_OUTPUT=$(btrfs scrub start -Bd "$MOUNT_POINT" 2>&1)
    SCRUB_EXIT_CODE=$?
    set -e
fi

# Basic parse: look for "Error summary:" (for >0 errors), or non-zero exit code
ERRORS_FOUND=0
if [[ "$SCRUB_EXIT_CODE" -ne 0 ]]; then
    ERRORS_FOUND=1
elif echo "$SCRUB_OUTPUT" | grep --quiet "Error summary:.*[1-9]"; then
    # e.g., "Error summary:    verify=1"
    ERRORS_FOUND=1
elif echo "$SCRUB_OUTPUT" | grep --quiet "unrecoverable errors:"; then
    ERRORS_FOUND=1
fi

if [[ "$ERRORS_FOUND" -eq 1 ]]; then
    TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
    # Sanitize mount point for log file name
    SAFE_MOUNT=$(echo "$MOUNT_POINT" | tr '/' '_')
    LOG_FILE="$LOG_DIR/scrub-error${SAFE_MOUNT}_${TIMESTAMP}.log"
    
    # Write to log file
    echo "$SCRUB_OUTPUT" > "$LOG_FILE"
    
    # Make the log file inherit the owner of its parent directory (LOG_DIR)
    DIR_OWNER=$(stat --format='%U:%G' "$LOG_DIR" 2>/dev/null || echo "")
    if [[ -n "$DIR_OWNER" ]]; then
        chown "$DIR_OWNER" "$LOG_FILE"
    fi
    
    # Notify user via DBus
    TARGET_UID=$(id --user "$TARGET_USER" 2>/dev/null || echo "")
    if [[ -n "$TARGET_UID" ]]; then
        DBUS_PATH="/run/user/$TARGET_UID/bus"
        if [[ -S "$DBUS_PATH" ]]; then
            # Run notify-send as the target user
            sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=$DBUS_PATH" \
                notify-send "CRITICAL: Btrfs Scrub Error" \
                "Scrub on $MOUNT_POINT finished with errors.\nLog written to:\n$LOG_FILE" \
                --urgency=critical --icon=drive-harddisk
        else
            echo "Warning: DBus path $DBUS_PATH not found for user $TARGET_USER. Notification not sent." >> "$LOG_FILE"
        fi
    else
         echo "Warning: UID for target user $TARGET_USER not found. Notification not sent." >> "$LOG_FILE"
    fi
fi

exit $SCRUB_EXIT_CODE
