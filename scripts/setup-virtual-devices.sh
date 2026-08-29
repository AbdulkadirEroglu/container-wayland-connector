#!/usr/bin/env bash
# Phase 7 test fixture: create virtual serial, camera, and CAN devices on
# the host so containers can be tested against hardware-shaped interfaces
# without needing real hardware (see docs/devices.md). The host creates
# and owns these, matching the project's host/container device-ownership
# split (README §8, §16) - containers just consume them like any other
# /dev entry or network interface.
#
# One-time host package needed for the virtual camera only (not done by
# this script - a real system package install):
#   sudo pacman -S v4l2loopback-dkms
#
# CAN and camera are genuine host-owned virtual devices/interfaces, shared
# with the container the same way real /dev/dri or network interfaces
# already are. Serial is different: a PTY's /dev/pts/N node only exists
# inside the mount namespace that created it, so it's created INSIDE the
# container instead (containers/ros-jazzy/setup-virtual-serial.sh) - see
# docs/devices.md.
#
# Usage: ./setup-virtual-devices.sh <container-name>
set -euo pipefail

CONTAINER="${1:?usage: setup-virtual-devices.sh <container-name>}"
STATE_DIR="${HOME}/.cache/container-wayland-connector/devices"
mkdir -p "${STATE_DIR}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "--- Virtual CAN (vcan0) ---"
if ! ip link show vcan0 >/dev/null 2>&1; then
    sudo modprobe vcan
    sudo ip link add dev vcan0 type vcan
fi
sudo ip link set up vcan0
echo "vcan0 is up."

python3 "${SCRIPT_DIR}/virtual-can-pattern.py" vcan0 \
    > "${STATE_DIR}/can-pattern.log" 2>&1 &
echo $! > "${STATE_DIR}/can-pattern.pid"
echo "Feeding CAN pattern onto vcan0 (PID $(cat "${STATE_DIR}/can-pattern.pid"))."

echo
echo "--- Virtual serial (linked PTY pair, created inside the container) ---"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
if distrobox enter --root "${CONTAINER}" -- bash -lc \
    "bash '${REPO_DIR}/containers/ros-jazzy/setup-virtual-serial.sh'"; then
    :
else
    echo "FAIL: see output above (is socat installed in the container? run"
    echo "containers/ros-jazzy/install-device-tools.sh first)."
fi

echo
echo "--- Virtual camera (v4l2loopback) ---"
if ! lsmod | grep -q '^v4l2loopback'; then
    if ! modinfo v4l2loopback >/dev/null 2>&1; then
        echo "v4l2loopback kernel module not installed. Install it with:"
        echo "  sudo pacman -S v4l2loopback-dkms"
        echo "then re-run this script."
    else
        sudo modprobe v4l2loopback video_nr=10 card_label="VirtualCam" exclusive_caps=1
    fi
fi
if [ -e /dev/video10 ]; then
    ffmpeg -re -f lavfi -i "testsrc=size=640x480:rate=15" -vf format=yuv420p -f v4l2 /dev/video10 \
        > "${STATE_DIR}/ffmpeg.log" 2>&1 &
    echo $! > "${STATE_DIR}/ffmpeg.pid"
    echo "/dev/video10 ready, feeding ffmpeg testsrc pattern (PID $(cat "${STATE_DIR}/ffmpeg.pid"))."
else
    echo "/dev/video10 not present (see message above)."
fi

echo
echo "State/PIDs recorded in ${STATE_DIR}."
echo "Tear down with: ./scripts/teardown-virtual-devices.sh"
