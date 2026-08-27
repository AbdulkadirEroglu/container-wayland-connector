#!/usr/bin/env bash
# Phase 8 (desktop integration): export a container's application as a
# host launcher entry via `distrobox-export`.
#
# Usage: ./export-apps.sh <container-name> <app-binary-or-desktop-file>
set -euo pipefail

CONTAINER="${1:?usage: export-apps.sh <container-name> <app>}"
APP="${2:?usage: export-apps.sh <container-name> <app>}"

distrobox enter "${CONTAINER}" -- distrobox-export --app "${APP}"
