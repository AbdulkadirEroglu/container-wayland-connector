#!/usr/bin/env bash
# Tear down the virtual devices created by setup-virtual-devices.sh /
# containers/ros-jazzy/setup-virtual-serial.sh.
#
# Usage: ./teardown-virtual-devices.sh <container-name>
set -uo pipefail

CONTAINER="${1:?usage: teardown-virtual-devices.sh <container-name>}"
STATE_DIR="${HOME}/.cache/container-wayland-connector/devices"

# ffmpeg/can-pattern.pid are host PIDs; socat/serial-pattern.pid are PIDs
# inside the container's own PID namespace (created by setup-virtual-serial.sh
# there), so they need killing via distrobox, not a plain host `kill`.
for pidfile in ffmpeg.pid can-pattern.pid; do
    f="${STATE_DIR}/${pidfile}"
    if [ -f "${f}" ]; then
        pid="$(cat "${f}")"
        if kill "${pid}" 2>/dev/null; then
            echo "Stopped ${pidfile%.pid} (PID ${pid}, host)"
        fi
        rm -f "${f}"
    fi
done

for pidfile in socat.pid serial-pattern.pid; do
    f="${STATE_DIR}/${pidfile}"
    if [ -f "${f}" ]; then
        pid="$(cat "${f}")"
        if distrobox enter --root "${CONTAINER}" -- bash -lc "kill ${pid}" 2>/dev/null; then
            echo "Stopped ${pidfile%.pid} (PID ${pid}, in-container)"
        fi
        rm -f "${f}"
    fi
done

if ip link show vcan0 >/dev/null 2>&1; then
    sudo ip link delete vcan0 && echo "Removed vcan0"
fi

if lsmod | grep -q '^v4l2loopback'; then
    sudo modprobe -r v4l2loopback && echo "Unloaded v4l2loopback"
fi

rm -rf "${STATE_DIR}"
echo "Teardown complete."
