#!/usr/bin/env bash
# Phase 7: create the virtual serial PTY pair and pattern writer INSIDE
# the container. Must run here, not on the host - /dev/pts is a distinct
# devpts instance per mount namespace, so a PTY created on the host isn't
# visible inside the container (confirmed while testing; see
# docs/devices.md's note on this).
#
# Run inside the container: distrobox enter --root ros-jazzy -- bash containers/ros-jazzy/setup-virtual-serial.sh
set -euo pipefail

STATE_DIR="${HOME}/.cache/container-wayland-connector/devices"
mkdir -p "${STATE_DIR}"
SERIAL_A="${STATE_DIR}/ttyV0"
SERIAL_B="${STATE_DIR}/ttyV1"
rm -f "${SERIAL_A}" "${SERIAL_B}"

# setsid + stdin from /dev/null: this script runs inside a `distrobox
# enter -- CMD` exec session that exits once this script finishes. A
# plain `cmd &` background job is a child of that session and gets torn
# down with it; setsid detaches it into its own session so it survives.
setsid socat -d -d "pty,raw,echo=0,link=${SERIAL_A}" "pty,raw,echo=0,link=${SERIAL_B}" \
    < /dev/null > "${STATE_DIR}/socat.log" 2>&1 &
disown
echo $! > "${STATE_DIR}/socat.pid"

for _ in $(seq 1 20); do
    [ -e "${SERIAL_A}" ] && [ -e "${SERIAL_B}" ] && break
    sleep 0.1
done

if [ ! -e "${SERIAL_A}" ] || [ ! -e "${SERIAL_B}" ]; then
    echo "FAIL: socat didn't create the PTY pair - see ${STATE_DIR}/socat.log" >&2
    exit 1
fi

# The repo is shared with the host at the same path (confirmed working
# since Phase 1), so the pattern generator can be run straight from there
# without duplicating it into the container.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
setsid python3 "${REPO_DIR}/scripts/virtual-serial-pattern.py" "${SERIAL_A}" \
    < /dev/null > "${STATE_DIR}/serial-pattern.log" 2>&1 &
disown
echo $! > "${STATE_DIR}/serial-pattern.pid"

echo "Serial pair ready (inside container): ${SERIAL_A} <-> ${SERIAL_B}"
echo "Feeding pattern into ${SERIAL_A} (PID $(cat "${STATE_DIR}/serial-pattern.pid"), container-local)."
