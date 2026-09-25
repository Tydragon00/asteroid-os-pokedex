#!/usr/bin/env bash
#
# Follow poke-dex, launcher and booster logs on the watch.
#
# Usage: tools/watch-logs.sh [app|all|follow|errors|status]
#
#   app      poke-dex / invoker / launcher / booster output (default)
#   all      launcher and booster streams side by side, prefixed
#   follow   raw journal tail
#   errors   recent error and failure lines
#   status   one-shot package, file and library diagnostics
#
# The watch's root SSH is disabled and the journal needs root, so everything
# goes through the empty sudo password of the unprivileged user.
#
# Environment:
#   WATCH  ssh target (default ceres@192.168.2.15)
#
set -euo pipefail

WATCH="${WATCH:-ceres@192.168.2.15}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
SSH=(ssh "${SSH_OPTS[@]}" "$WATCH")
MODE="${1:-app}"

journal() {
    "${SSH[@]}" "printf '\n' | sudo -S -k journalctl $*"
}

case "$MODE" in
    app)
        exec "${SSH[@]}" "printf '\n' | sudo -S -k journalctl -f -n 40 --no-pager _SYSTEMD_USER_UNIT=asteroid-launcher.service -t invoker -t booster-asteroid-qt6 -t booster-qt6"
        ;;
    all)
        journal -f -n 20 --no-pager _SYSTEMD_USER_UNIT=asteroid-launcher.service \
            | sed -u 's/^/[launcher] /' &
        launcher_pid=$!
        journal -f -n 20 --no-pager -t booster-asteroid-qt6 -t booster-qt6 \
            | sed -u 's/^/[booster]  /' &
        booster_pid=$!
        trap 'kill $launcher_pid $booster_pid 2>/dev/null || true' EXIT
        wait
        ;;
    follow)
        exec "${SSH[@]}" "printf '\n' | sudo -S -k journalctl -f -n 40 --no-pager"
        ;;
    errors)
        journal -b --no-pager -n 1000 | grep -iE 'error|fail|poke-dex|invoker' | tail -80 || true
        ;;
    status)
        "${SSH[@]}" "printf '\n' | sudo -S -k sh -c '
            echo === package ===
            opkg status poke-dex 2>/dev/null | grep -E \"^(Package|Version|Status|Installed-Time)\" || echo \"poke-dex is not installed\"
            echo === files ===
            ls -l /usr/bin/poke-dex /usr/lib/libpoke-dex.so /usr/share/applications/poke-dex.desktop 2>&1
            echo === database ===
            ls -l /usr/share/pokemon/ 2>&1
            echo === library ===
            strings /usr/lib/libpoke-dex.so 2>/dev/null | grep -m4 -E \"^libQt[56]\" || echo \"could not read the library\"
            echo === recent log ===
            journalctl -b --no-pager -n 25 _SYSTEMD_USER_UNIT=asteroid-launcher.service -t invoker -t booster-asteroid-qt6 2>/dev/null | tail -25
        '"
        ;;
    *)
        echo "usage: $0 [app|all|follow|errors|status]" >&2
        exit 2
        ;;
esac
