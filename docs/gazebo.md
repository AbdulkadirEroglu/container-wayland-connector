# Gazebo

See the main README §5 (Rendering Model) and the roadmap Phase 5 (README
§30 in `containerized-robotics-desktop-README.md`).

Gazebo Harmonic is the release paired with ROS 2 Jazzy / Ubuntu 24.04,
installed via the `ros-jazzy-ros-gz` metapackage
(`containers/ros-jazzy/install-gazebo.sh`).

## Setup

```bash
distrobox enter --root ros-jazzy -- bash containers/ros-jazzy/install-gazebo.sh
./scripts/test-gazebo.sh ros-jazzy
```

(`--root`: this host's Docker is rootful-only; see
[`troubleshooting.md`](troubleshooting.md#omarchy-host--rootful-docker--distrobox-enter----cmd-path-quirk).
`test-gazebo.sh` already applies `--root` itself.)

## Expected known issue — same root cause as RViz2

Gazebo's GUI (`gz-sim`/`gz-gui`) is built on Qt + Ogre2 (OGRE-Next), the
same combination that breaks RViz2 under native Wayland (see
[`wayland.md`](wayland.md#known-issue-ogre-based-apps-rviz2-need-qt_qpa_platformxcb)):
Qt's Wayland platform plugin hands Ogre2 a native Wayland surface, but
Ogre2 has no native Wayland windowing backend yet and expects a GLX/X11
window handle.

This is confirmed upstream, not a guess — the Gazebo project ships the
identical `QT_QPA_PLATFORM=xcb` workaround itself
([gazebosim/gz-sim#2526](https://github.com/gazebosim/gz-sim/pull/2526),
explicitly modeled on the RViz2 fix), auto-applying it whenever Wayland
is detected and the user hasn't set `QT_QPA_PLATFORM` themselves. Native
Wayland windowing for OGRE-Next is still tracked as unimplemented upstream
([OGRECave/ogre-next#41](https://github.com/OGRECave/ogre-next/issues/41)).

So: try `./scripts/test-gazebo.sh ros-jazzy` unmodified first (Gazebo may
already self-apply the xcb workaround). If it still fails to create its
render window, force it explicitly:

```bash
QT_QPA_PLATFORM=xcb ./scripts/test-gazebo.sh ros-jazzy
```

## Known issue — GUI/server can't find each other (Gazebo Transport discovery)

`gz sim <world>` forks a server subprocess and a GUI subprocess that talk
over Gazebo Transport (gz-transport), which defaults to UDP multicast for
peer discovery. On this host that discovery never completes: the server
loads the world fully and registers all its services, but the GUI sits
forever on `GUI requesting list of world names. The server may be busy
downloading resources.` — a generic fallback message, not an actual
download; the two processes simply never see each other.

Confirmed by bisecting: running `gz sim -s` (server) and `gz sim -g` (GUI)
in separate terminals reproduced the identical hang, so it isn't specific
to how the combined `gz sim <world>` command forks — the discovery
transport itself isn't working across the two processes in this
container's networking.

**Likely root cause (per Phase 6 investigation, `docs/ros-networking.md`):**
the `ros-jazzy` container runs with host networking, exposing both the
real Wi-Fi interface (`wlp7s0`) and an unused, `NO-CARRIER`/`DOWN`
`docker0` bridge (`172.17.0.1`) side by side. `GZ_IP` autodetection
likely picks the dead `docker0` address rather than a working interface.
ROS 2's Fast DDS discovery, tested in Phase 6, enumerated interfaces more
robustly and worked with zero extra configuration in the same container -
this appears to be a Gazebo Transport-specific autodetection weakness,
not a fundamental container-networking limitation.

**Fix:** pin both processes to a known-reachable address instead of
relying on multicast autodiscovery:

```bash
GZ_IP=127.0.0.1 gz sim ...
```

`test-gazebo.sh` sets `GZ_IP=127.0.0.1` by default now; override it with
the `GZ_IP` env var if a different container network setup needs it.

**Update (Phase 6):** checked - ROS 2's DDS layer did *not* hit the same
problem in this container (see `docs/ros-networking.md`); `test-network.sh`
passed cleanly with zero extra config. So this looks like a Gazebo
Transport-specific autodetection weakness (see root cause note above),
not a general container-networking limitation affecting every discovery
mechanism.

## Bridging Gazebo topics to ROS or another container on this same host

Since this container runs with host networking (`docs/ros-networking.md`),
another process sharing that same host network - a `ros_gz_bridge` node,
or a separate container that's *also* host-networked - sees the exact
same loopback interface. `GZ_IP=127.0.0.1` (already `test-gazebo.sh`'s
default) is sufficient for that case; give the other process the same
`GZ_IP=127.0.0.1`. No real interface IP or relay needed here - that's
only for the next case.

## Reaching a genuinely separate machine (real robot on the LAN) — GZ_RELAY

Don't reach for `GZ_IP=<wlp7s0's address>` to bridge to a different
physical machine - it was tried and didn't work, which matches a known,
documented gz-transport limitation, not a misconfiguration:
gz-transport's peer discovery relies on UDP multicast, routers don't
forward multicast across subnets at all, and multicast over Wi-Fi
specifically is unreliable even on the same subnet (APs frequently drop
or fail to forward it - [gazebosim/gz-transport#114](https://github.com/gazebosim/gz-transport/issues/114)).
Setting `GZ_IP` only changes the advertised return address; the
discovery announcement itself still goes out as multicast and can fail
to leave the NIC at all.

The documented fix is [`GZ_RELAY`](https://gazebosim.org/api/transport/14/relay.html),
which adds a unicast relay instead of depending on multicast discovery.
After the relay connects the two networks, nodes still exchange the
actual pub/sub data directly, so every endpoint must be reachable from
the other side (no NAT in between, or NAT it separately).

```bash
# On this machine:
GZ_IP=192.168.1.226 GZ_RELAY=<other machine's LAN IP> GZ_PARTITION=shared gz sim ...

# On the other machine (mirrored - same GZ_PARTITION, addresses swapped):
GZ_IP=<other machine's LAN IP> GZ_RELAY=192.168.1.226 GZ_PARTITION=shared gz topic -e -t /foo
```

Only one relay link is needed for bidirectional communication.
`GZ_PARTITION` must match on both ends or they won't consider each other
peers at all.

Untested here - no second machine available yet. Revisit once Phase 7
hardware or a second host is on the LAN to actually validate this against
`docs/ros-networking.md`'s deferred "container ↔ robot on LAN" case.

## Phase 5 Result — 2026-08-29

Host: Omarchy (Hyprland), rootful Docker backend.
Container: `ros-jazzy` (Ubuntu 24.04), Gazebo Harmonic (`gz-sim` 8.11.0)
via `ros-jazzy-ros-gz`.

- The Wayland/Ogre2 rendering concern flagged above did **not** end up
  being the blocker: with `QT_QPA_PLATFORM=xcb`, Qt cleanly initializes
  XCB/GLX and creates its main window (confirmed via
  `QT_LOGGING_RULES=qt.qpa.*=true` trace — no crash, no missing window).
- The actual blocker was Gazebo Transport discovery between the server
  and GUI subprocesses, fixed with `GZ_IP=127.0.0.1` (see above).
- With both the xcb and GZ_IP fixes applied, `gz sim shapes.sdf` renders
  correctly on the host Hyprland compositor.

**Verdict: passed** (with `QT_QPA_PLATFORM=xcb` + `GZ_IP=127.0.0.1`, both
now defaulted/documented in `test-gazebo.sh`). Native-Wayland rendering
for Gazebo remains untested since xcb was needed first for a fair test —
revisit once OGRE-Next gains native Wayland support (or via the user's
own in-progress fork, see project notes) to see if xcb is still required.
