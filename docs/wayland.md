# Wayland Integration

See the main README §4–§5 (Why Wayland Helps, Rendering Model).

## Phase 1 Result — 2026-08-27

Host: Omarchy (Hyprland), Docker backend.
Container: `ros-jazzy` (Ubuntu 24.04, `distrobox create --nvidia`).

Ran `glxgears` from inside the container via
`distrobox enter ros-jazzy -- glxgears`.

- Window appeared directly on the host Hyprland compositor — no nested
  desktop, no VNC/RDP.
- Host window rules and theming were applied correctly, i.e. the
  container app is indistinguishable from a native host app to
  Hyprland.
- No manual Wayland socket wiring was needed — Distrobox's default
  host integration was sufficient.

**Verdict: passed.** Phase 1 acceptance criteria (README §28,
Graphics: "Wayland GUI application launches from container") met.
