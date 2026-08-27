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

## Known Issue — Ogre-based apps (RViz2) need QT_QPA_PLATFORM=xcb

Plain GLX apps (`glxgears`) work fine unmodified. `rviz2` did not:

```
[ERROR] [rviz2]: rviz::RenderSystem: error creating render window:
RenderingAPIException: Invalid parentWindowHandle (wrong server or screen)
in GLXWindow::create ...
[ERROR] [rviz2]: Unable to create the rendering window after 100 tries
terminate called after throwing an instance of 'std::runtime_error'
```

**Cause:** RViz2's renderer (Ogre, via `rviz_ogre_vendor`) is GLX/X11-only
— it has no native Wayland backend. In a real Wayland session, Qt's
default platform plugin is `wayland`, so Qt creates a native Wayland
surface for the RViz window. Ogre then tries to attach a GLX context to
that surface as if it were an X11 window, and the X server rejects it
(wrong server/screen) since it isn't one.

**Fix:** force Qt onto XCB so the whole app (window + GL context) runs
through XWayland instead of native Wayland:

```bash
QT_QPA_PLATFORM=xcb rviz2
```

Confirmed working: window renders correctly on the host Hyprland
compositor.

This matches the risk the main README already called out in §31
("Wayland-only applications", "XWayland fallback"). Expect any other
Ogre/older-Qt-GL app (Gazebo's GUI, potentially) to need the same
treatment — check this first before assuming a new failure is Distrobox-
or NVIDIA-related.
