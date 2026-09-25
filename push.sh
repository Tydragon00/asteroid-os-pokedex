#!/usr/bin/env bash
#
# Build the poke-dex ipk with the Qt6 SDK and install it on the watch.
#
# The watch runs an AsteroidOS 2.2 nightly (Qt6): root SSH is disabled and the
# unprivileged user has an empty sudo password, so privileged steps go through
# "printf '\n' | sudo -S".
#
# Usage: ./push.sh
#
# Environment:
#   QT6_SDK_ENV  path to the Qt6 SDK environment-setup script (required), e.g.
#                ~/asteroid-sdk/qt6/environment-setup-armv7vehf-neon-oe-linux-gnueabi
#   WATCH        ssh target (default ceres@192.168.2.15)
#
# Requires src/db/pokemon.db and src/images; run ./init_app.sh first.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

WATCH="${WATCH:-ceres@192.168.2.15}"

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
SSH=(ssh "${SSH_OPTS[@]}" "$WATCH")
SCP=(scp "${SSH_OPTS[@]}")

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m!!!\033[0m %s\n' "$*" >&2; exit 1; }

[ -f src/db/pokemon.db ] || fail "missing src/db/pokemon.db - run ./init_app.sh first"
[ -d src/images ] || fail "missing src/images - run ./init_app.sh first"
[ -n "${QT6_SDK_ENV:-}" ] || fail "QT6_SDK_ENV is not set: export QT6_SDK_ENV=/path/to/qt6-sdk/environment-setup-armv7vehf-neon-oe-linux-gnueabi (see README)"
[ -f "$QT6_SDK_ENV" ] || fail "QT6_SDK_ENV points at a missing file: $QT6_SDK_ENV"

rm -rf build

# shellcheck disable=SC1091
source "$QT6_SDK_ENV"

# asteroid-generate-desktop lives in the target sysroot and runs on the host
# through qemu binfmt.
export CMAKE_PROGRAM_PATH="$OECORE_TARGET_SYSROOT/usr/bin/"

info "Building with $(cmake --version | head -1)"
cmake -B build -DCMAKE_INSTALL_PREFIX:PATH=/usr
cmake --build build --target package

ipk_files=(build/poke-dex*.ipk)
[ -e "${ipk_files[0]}" ] || fail "no ipk produced in build/"
ipk_name="$(basename "${ipk_files[0]}")"

info "Installing ${ipk_name} on ${WATCH#*@}"
"${SCP[@]}" "${ipk_files[0]}" "$WATCH:/tmp/"
"${SSH[@]}" "printf '\n' | sudo -S -k sh -c 'opkg remove poke-dex 2>/dev/null; opkg install /tmp/${ipk_name}'"
"${SSH[@]}" "rm -f /tmp/${ipk_name}"

info "Installed. Follow the logs with tools/watch-logs.sh"
