#!/usr/bin/env bash
# Verify host GPU access before relying on it inside a container.
set -uo pipefail

echo "--- /dev/dri ---"
ls -l /dev/dri 2>/dev/null || echo "no /dev/dri found"

echo
echo "--- NVIDIA ---"
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi
else
    echo "nvidia-smi not found (no NVIDIA driver on host, or not installed)"
fi

echo
echo "--- OpenGL (requires mesa-utils / glxinfo) ---"
if command -v glxinfo >/dev/null 2>&1; then
    glxinfo | grep -E "OpenGL vendor|OpenGL renderer" || true
else
    echo "glxinfo not found"
fi

echo
echo "--- Vulkan (requires vulkan-tools) ---"
if command -v vulkaninfo >/dev/null 2>&1; then
    vulkaninfo --summary 2>/dev/null || echo "vulkaninfo failed"
else
    echo "vulkaninfo not found"
fi
