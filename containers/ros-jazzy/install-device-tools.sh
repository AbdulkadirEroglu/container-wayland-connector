#!/usr/bin/env bash
# Phase 7: device-testing tools inside the ros-jazzy container.
# Run inside the container: distrobox enter --root ros-jazzy -- bash containers/ros-jazzy/install-device-tools.sh
# (drop --root if your host's Docker isn't rootful-only; see docs/troubleshooting.md)
set -euo pipefail

sudo apt-get update
sudo apt-get install -y can-utils v4l-utils socat

echo
echo "Device tools installed (can-utils, v4l-utils, socat)."
echo "Verify manually with:"
echo "  candump vcan0"
echo "  v4l2-ctl --list-devices"
