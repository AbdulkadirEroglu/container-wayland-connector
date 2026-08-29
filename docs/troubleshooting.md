# Troubleshooting

Known risk areas to watch for (see main README §31):

- NVIDIA userspace / kernel ABI mismatches
- Vulkan ICD and loader configuration
- Gazebo rendering / RViz-Ogre behavior
- Wayland-only applications and XWayland fallback
- ROS DDS discovery and multicast
- USB permissions
- D-Bus integration
- PipeWire sockets and permissions

Entries will be added here as issues are hit and resolved during
prototyping.

## Omarchy host — rootful Docker + `distrobox enter -- CMD` PATH quirk

**Symptom 1:** `distrobox enter ros-jazzy` (no flag) either fails to reach
the daemon, or lands you in a container session where things behave
unexpectedly.

**Cause:** on this Omarchy host, Docker is configured rootful-only — the
interactive user isn't set up for passwordless access to the daemon
socket. Distrobox needs `--root` to talk to it.

**Fix:** always call `distrobox enter --root <container> -- ...` (and
`distrobox create --root ...` if container creation ever needs it too)
on this host. All scripts in `scripts/` do this already.

**Symptom 2:** a command that works fine when typed interactively inside
the container (`distrobox enter --root ros-jazzy` then run `gz` by hand)
fails with `command not found` when run non-interactively, even wrapped
in a login shell (`distrobox enter --root ros-jazzy -- bash -lc 'gz ...'`).

**Cause:** confirmed via `which gz` — the binary lives at
`/opt/ros/jazzy/opt/gz_tools_vendor/bin/gz`, only added to `PATH` by
sourcing `/opt/ros/jazzy/setup.bash`. `install-ros.sh` appends that
source line to `~/.bashrc`, but `~/.bashrc` starts with an
interactive-shell guard (`case $- in *i*) ;; *) return;; esac`) — under
`bash -lc` (non-interactive) that guard returns immediately and the ROS
source line is never reached, so none of the `/opt/ros/jazzy/opt/*/bin`
directories it adds (including `gz`'s) make it onto `PATH`. This applies
to any ROS-vendored binary, not just `gz`.

**Fix:** don't rely on the profile chain — source `/opt/ros/jazzy/setup.bash`
explicitly in the command: `distrobox enter --root <container> -- bash -lc
"[ -r /opt/ros/jazzy/setup.bash ] && . /opt/ros/jazzy/setup.bash; CMD"`.
All scripts in `scripts/` do this already.

## Gazebo Transport (and likely ROS DDS) multicast discovery fails in-container

**Symptom:** `gz sim <world>` hangs forever with the GUI repeating `GUI
requesting list of world names. The server may be busy downloading
resources.` even though the server process loaded the world completely
and registered all its services (confirmed by running server (`gz sim
-s`) and GUI (`gz sim -g`) separately — both load fine standalone, but
never see each other).

**Cause:** Gazebo Transport defaults to UDP multicast for peer discovery,
which isn't completing between the two subprocesses on this host's
container networking.

**Fix:** pin both processes to a known address instead: `GZ_IP=127.0.0.1
gz sim ...`. `scripts/test-gazebo.sh` defaults to this now. Full writeup
in [`docs/gazebo.md`](gazebo.md#known-issue--guiserver-cant-find-each-other-gazebo-transport-discovery).

**Update (Phase 6):** this turned out to be specific to Gazebo Transport,
not a general container-networking limitation. ROS 2's DDS discovery
(`scripts/test-network.sh`) worked with zero extra config in the same
container. Root cause is more likely Gazebo Transport's `GZ_IP`
autodetection picking the container's unused, `DOWN` `docker0` bridge
address instead of the real interface (`docs/ros-networking.md` has the
interface list). See [`docs/ros-networking.md`](ros-networking.md) for
the DDS-specific env knobs (`ROS_AUTOMATIC_DISCOVERY_RANGE`,
`ROS_STATIC_PEERS`) to reach for only if DDS discovery ever does fail
similarly in a different setup.
