#!/usr/bin/env bash
# Verify the host has what this project needs before creating containers.
set -uo pipefail

ok=0
fail=0

check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "[ OK ] ${desc}"
        ok=$((ok + 1))
    else
        echo "[FAIL] ${desc}"
        fail=$((fail + 1))
    fi
}

check "distrobox installed" command -v distrobox
check "podman or docker installed" bash -c 'command -v podman || command -v docker'
check "Wayland session active" bash -c '[ -n "${WAYLAND_DISPLAY:-}" ]'
check "XDG_RUNTIME_DIR set" bash -c '[ -n "${XDG_RUNTIME_DIR:-}" ]'

echo
echo "${ok} passed, ${fail} failed."
[ "${fail}" -eq 0 ]
