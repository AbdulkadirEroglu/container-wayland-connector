#!/usr/bin/env bash
# Phase 8 (desktop integration): export a container's application as a
# host launcher entry via `distrobox-export`.
#
# Usage: ./export-apps.sh <container-name> <app-binary-or-desktop-file>
set -euo pipefail

CONTAINER="${1:?usage: export-apps.sh <container-name> <app>}"
APP="${2:?usage: export-apps.sh <container-name> <app>}"

# --root: this host's Docker daemon is rootful-only (see docs/troubleshooting.md).
# Explicitly source ROS's setup.bash (see test-wayland.sh comment / docs/troubleshooting.md
# for why `bash -lc` alone doesn't pick it up from ~/.bashrc).
distrobox enter --root "${CONTAINER}" -- bash -lc "[ -r /opt/ros/jazzy/setup.bash ] && . /opt/ros/jazzy/setup.bash; distrobox-export --app '${APP}'"
