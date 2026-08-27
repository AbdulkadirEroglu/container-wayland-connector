#!/usr/bin/env bash
# Run inside the ros-jazzy container (via `distrobox enter ros-jazzy`).
set -euo pipefail

PACKAGES_FILE="$(dirname "$0")/packages.txt"

sudo apt-get update

# shellcheck disable=SC2013
for pkg in $(grep -v '^#' "${PACKAGES_FILE}" | grep -v '^\s*$'); do
    sudo apt-get install -y "${pkg}"
done

echo "Base packages installed."
echo "ROS 2 Jazzy installation is not yet automated here (Phase 3 of the roadmap)."
