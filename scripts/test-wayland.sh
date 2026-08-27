#!/usr/bin/env bash
# Phase 1 acceptance check: launch a simple Wayland GUI app inside a
# distrobox container and confirm it appears on the host compositor.
#
# Usage: ./test-wayland.sh <container-name> [app]
set -euo pipefail

CONTAINER="${1:?usage: test-wayland.sh <container-name> [app]}"
APP="${2:-weston-terminal}"

echo "Launching '${APP}' inside '${CONTAINER}'..."
distrobox enter "${CONTAINER}" -- "${APP}"
