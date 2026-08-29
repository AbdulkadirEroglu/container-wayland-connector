#!/usr/bin/env bash
# Phase 7 acceptance check: serial/camera/CAN device access from inside
# the container, using the virtual devices created by
# setup-virtual-devices.sh (see docs/devices.md) so no real hardware is
# required.
#
# Usage: ./test-devices.sh <container-name> [timeout-seconds]
set -uo pipefail

CONTAINER="${1:?usage: test-devices.sh <container-name> [timeout-seconds]}"
TIMEOUT="${2:-5}"
STATE_DIR="${HOME}/.cache/container-wayland-connector/devices"
SERIAL_B="${STATE_DIR}/ttyV1"
V4L2_LOG="$(mktemp)"
trap 'rm -f "${V4L2_LOG}"' EXIT

pass=0
fail=0

echo "=== Serial (virtual PTY: ${SERIAL_B}) ==="
# -L, not -e: the symlink's target (/dev/pts/N) is only resolvable inside
# the container's own devpts instance, so following it from the host
# (-e) would report "not found" even when everything is fine. Existence
# of the symlink itself is all that's checkable from here - the real
# check happens inside the container below.
if [ ! -L "${SERIAL_B}" ]; then
    echo "FAIL: ${SERIAL_B} not found - run ./scripts/setup-virtual-devices.sh first."
    fail=$((fail + 1))
else
    LINE="$(distrobox enter --root "${CONTAINER}" -- bash -lc "timeout ${TIMEOUT} head -n1 '${SERIAL_B}'" 2>/dev/null)"
    if [[ "${LINE}" == PATTERN* ]]; then
        echo "PASS: read from container: ${LINE}"
        pass=$((pass + 1))
    else
        echo "FAIL: no valid pattern line read within ${TIMEOUT}s (got: '${LINE}')"
        echo "Make sure ./scripts/setup-virtual-devices.sh <container> has been run"
        echo "(it creates the PTY pair inside the container - see docs/devices.md)."
        fail=$((fail + 1))
    fi
fi

echo
echo "=== CAN (vcan0) ==="
if ! ip link show vcan0 >/dev/null 2>&1; then
    echo "FAIL: vcan0 not found - run ./scripts/setup-virtual-devices.sh first."
    fail=$((fail + 1))
else
    CANOUT="$(distrobox enter --root "${CONTAINER}" -- bash -lc "timeout ${TIMEOUT} candump -n 1 vcan0" 2>/dev/null)"
    if [ -n "${CANOUT}" ]; then
        echo "PASS: candump received a frame from container: ${CANOUT}"
        pass=$((pass + 1))
    else
        echo "FAIL: candump received nothing within ${TIMEOUT}s."
        fail=$((fail + 1))
    fi
fi

echo
echo "=== Camera (/dev/video10) ==="
if [ ! -e /dev/video10 ]; then
    echo "FAIL: /dev/video10 not found - run ./scripts/setup-virtual-devices.sh first."
    fail=$((fail + 1))
else
    if distrobox enter --root "${CONTAINER}" -- bash -lc \
        "v4l2-ctl --device=/dev/video10 --stream-mmap --stream-count=1 --stream-to=/dev/null" \
        > "${V4L2_LOG}" 2>&1; then
        echo "PASS: captured a frame from /dev/video10 inside the container."
        pass=$((pass + 1))
    else
        echo "FAIL: frame capture failed:"
        cat "${V4L2_LOG}"
        fail=$((fail + 1))
    fi
fi

echo
echo "${pass} passed, ${fail} failed."
[ "${fail}" -eq 0 ]
