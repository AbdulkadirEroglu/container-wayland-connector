#!/usr/bin/env bash
set -euo pipefail

NAME="ros-jazzy"
IMAGE="ubuntu:24.04"

if distrobox list 2>/dev/null | grep -q "^${NAME}\b\|| ${NAME} |"; then
    echo "Container '${NAME}' already exists. Enter it with: distrobox enter --root ${NAME}"
    exit 0
fi

distrobox create \
    --name "${NAME}" \
    --image "${IMAGE}" \
    --nvidia \
    --yes

echo "Container '${NAME}' created."
echo "Next: distrobox enter --root ${NAME} -- bash $(dirname "$0")/setup.sh"
echo "(drop --root if your host's Docker isn't rootful-only; see docs/troubleshooting.md)"
