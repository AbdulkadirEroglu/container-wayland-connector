# NVIDIA Support

See the main README §7 (NVIDIA Support) and §28 (NVIDIA acceptance
tests).

## Phase 2 Result — 2026-08-27

Host: NVIDIA GeForce RTX 5080, driver 610.57.04.
Container: `ros-jazzy` (Ubuntu 24.04, created with `distrobox create --nvidia`).

- `glxinfo` inside the container reports:
  - `OpenGL vendor string: NVIDIA Corporation`
  - `OpenGL renderer string: NVIDIA GeForce RTX 5080/PCIe/SSE2`
  - i.e. hardware-accelerated rendering, not llvmpipe/software fallback.
- `vulkaninfo --summary` inside the container reports Vulkan Instance
  1.3.275 with `VK_KHR_wayland_surface` available.
- No host/container NVIDIA driver ABI mismatch observed — Distrobox's
  `--nvidia` flag correctly bound the host driver's userspace libraries
  into the container instead of installing a conflicting driver stack.

**Verdict: passed.** Phase 2 acceptance criteria (README §28, NVIDIA:
OpenGL hardware acceleration, Vulkan) met. CUDA availability not yet
tested.
