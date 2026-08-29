#!/usr/bin/env bash
# Phase 1 acceptance check: launch a simple Wayland GUI app inside a
# distrobox container and confirm it appears on the host compositor.
#
# Usage: ./test-wayland.sh <container-name> [app]
set -euo pipefail

CONTAINER="${1:?usage: test-wayland.sh <container-name> [app]}"
APP="${2:-weston-terminal}"

echo "Launching '${APP}' inside '${CONTAINER}'..."
# --root: this host's Docker daemon is rootful-only (see docs/troubleshooting.md).
# Explicitly source ROS's setup.bash: ~/.bashrc's interactive-shell guard
# skips the source line install-ros.sh puts there when run non-interactively
# via `bash -lc`, so PATH entries it adds (e.g. for ROS-provided GUI apps)
# would otherwise be missing.
distrobox enter --root "${CONTAINER}" -- bash -lc "[ -r /opt/ros/jazzy/setup.bash ] && . /opt/ros/jazzy/setup.bash; '${APP}'"
