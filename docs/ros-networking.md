# ROS Networking (DDS)

See the main README §15 (Networking and ROS DDS), which requires testing:

```text
container node ↔ container node
container node ↔ host
container node ↔ robot on LAN
DDS multicast discovery
ROS topics/services/actions
```

## Container networking mode

`test-network.sh`'s diagnostics confirmed the `ros-jazzy` container runs
with **host networking**, not a bridge: `ip addr` inside the container
shows the host's real Wi-Fi interface directly (`wlp7s0`,
`192.168.1.226/24`) alongside an unused, `NO-CARRIER`/`DOWN` `docker0`
bridge. This has two implications:

- **container ↔ host** isn't really a separate network boundary here at
  all - a process in the container and a process on the host share the
  same network stack. Nothing extra to prove beyond the container↔container
  case below.
- **container ↔ robot on LAN** has a real path to work over `wlp7s0`
  once hardware is available, since the container can already see and
  bind to that interface directly.
- This is also the likely root cause of Phase 5's Gazebo Transport
  discovery failure (`docs/gazebo.md`): with host networking exposing
  both `wlp7s0` and the stale `docker0`, `GZ_IP` autodetection probably
  picked the dead `docker0` address (`172.17.0.1`) instead of a working
  interface, while ROS 2's discovery enumerated interfaces more robustly
  and picked something usable without any extra configuration.

## Scope of automated testing here

- **container ↔ container node** (same container, two independent
  processes): automated by `scripts/test-network.sh` via
  `ros2 run demo_nodes_cpp talker`/`listener`.
- **container ↔ host**: not separately automated - see above, this is
  the same network stack, so the container↔container result already
  covers it in practice. By design the host also has no ROS installed
  (README §10), so there's no distinct host-side ROS node to test
  against anyway.
- **container ↔ robot on LAN**: not automated - requires real hardware
  on the network, which isn't available yet. Manual test plan: point a
  robot (or a second machine running `ros2 run demo_nodes_cpp talker`)
  at the same `ROS_DOMAIN_ID`, run `listener` in the `ros-jazzy`
  container, and confirm discovery across the LAN via `wlp7s0`. Revisit
  once hardware is available (Phase 7 territory may bring some in anyway).
  Note this is DDS, a separate discovery mechanism from Gazebo Transport -
  don't assume the same fix applies; see `docs/gazebo.md`'s `GZ_RELAY`
  section for the Gazebo-side equivalent of this same cross-machine
  problem (gz-transport's multicast discovery is documented as unreliable
  over Wi-Fi specifically, which is worth keeping in mind if DDS runs
  into something similar here).

## Relevant prior finding — Gazebo Transport hit this exact problem

Phase 5 (`docs/gazebo.md`) found that Gazebo Transport's default UDP
multicast discovery fails between two subprocesses in this container's
networking, fixed by pinning `GZ_IP=127.0.0.1` instead of relying on
autodiscovery. ROS 2's DDS layer (Fast DDS by default) uses a similar
multicast discovery mechanism, so if `test-network.sh` fails the same
way, don't treat it as a fresh mystery - try the same category of fix
first:

- `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` - restrict discovery to
  loopback instead of the default `SUBNET` multicast range.
- `ROS_STATIC_PEERS=<address>` - the direct ROS analogue of `GZ_IP`:
  bypass multicast entirely with an explicit peer list.
- `ROS_LOCALHOST_ONLY=1` - simplest hammer for same-host-only testing,
  but note this would also need to be *off* for the container↔LAN case,
  so it's a debugging tool here, not the final answer for that scenario.

`test-network.sh` forwards all of these through if set, and prints the
matching suggestion on failure.

## Phase 6 Result — 2026-08-29

Host: Omarchy, `ros-jazzy` container (host networking, confirmed above).

- `./scripts/test-network.sh ros-jazzy` passed on the first try, no extra
  env vars needed - `demo_nodes_cpp listener` received `talker`'s
  messages immediately (`I heard: [Hello World: 3..6]` etc.).
- Unlike Gazebo Transport (Phase 5), ROS 2's default Fast DDS discovery
  worked out of the box in this container, no `GZ_IP`-style pinning
  required. Likely explanation: host networking plus Fast DDS enumerating
  interfaces properly (see above), vs. Gazebo Transport apparently
  picking the dead `docker0` bridge address.
- container↔host: not distinctly testable/needed - same network stack
  (see above).
- container↔LAN robot: untested, no hardware available yet. Path is
  clear in principle (`wlp7s0` is directly reachable from the container).

**Verdict: passed** for the testable scope (container↔container,
container↔host). LAN robot case deferred pending hardware.
