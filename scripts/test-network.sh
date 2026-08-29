#!/usr/bin/env bash
# Phase 6 acceptance check: ROS 2 DDS discovery.
#
# Automates the "container node <-> container node" case from README §15/28:
# runs `ros2 run demo_nodes_cpp talker` and `listener` as two independent
# processes inside the container (mirrors the `gz sim -s`/`gz sim -g` split
# used to diagnose Phase 5's discovery issue) and checks whether the
# listener actually receives messages.
#
# "container <-> host" and "container <-> LAN robot" are NOT automated
# here (no ROS on the host by design, no robot hardware available) - see
# docs/ros-networking.md for how to test those manually.
#
# Usage: ./test-network.sh <container-name> [timeout-seconds]
#
# Env vars (all optional, forwarded into both talker and listener):
#   ROS_DOMAIN_ID
#   ROS_LOCALHOST_ONLY
#   ROS_AUTOMATIC_DISCOVERY_RANGE   (e.g. LOCALHOST, SUBNET) - try LOCALHOST
#                                    first if discovery fails the same way
#                                    Gazebo Transport's did (docs/gazebo.md).
#   ROS_STATIC_PEERS                explicit peer list, bypassing multicast
#                                    entirely - the ROS analogue of the
#                                    GZ_IP fix from Phase 5.
set -euo pipefail

CONTAINER="${1:?usage: test-network.sh <container-name> [timeout-seconds]}"
TIMEOUT="${2:-10}"

# --root: this host's Docker daemon is rootful-only (see docs/troubleshooting.md).
# Explicitly source ROS's setup.bash rather than relying on `bash -lc` to
# pick it up from ~/.bashrc (it won't - see docs/troubleshooting.md).
ROS_SETUP="[ -r /opt/ros/jazzy/setup.bash ] && . /opt/ros/jazzy/setup.bash"

ENV_ARGS=()
[ -n "${ROS_DOMAIN_ID:-}" ] && ENV_ARGS+=("ROS_DOMAIN_ID='${ROS_DOMAIN_ID}'")
[ -n "${ROS_LOCALHOST_ONLY:-}" ] && ENV_ARGS+=("ROS_LOCALHOST_ONLY='${ROS_LOCALHOST_ONLY}'")
[ -n "${ROS_AUTOMATIC_DISCOVERY_RANGE:-}" ] && ENV_ARGS+=("ROS_AUTOMATIC_DISCOVERY_RANGE='${ROS_AUTOMATIC_DISCOVERY_RANGE}'")
[ -n "${ROS_STATIC_PEERS:-}" ] && ENV_ARGS+=("ROS_STATIC_PEERS='${ROS_STATIC_PEERS}'")

LISTENER_LOG="$(mktemp)"
trap 'rm -f "${LISTENER_LOG}"' EXIT

echo "--- Diagnostics ---"
distrobox enter --root "${CONTAINER}" -- bash -lc \
    "${ROS_SETUP}; echo ROS_DOMAIN_ID=\${ROS_DOMAIN_ID:-0 (default)}; echo ROS_LOCALHOST_ONLY=\${ROS_LOCALHOST_ONLY:-unset}; echo ROS_AUTOMATIC_DISCOVERY_RANGE=\${ROS_AUTOMATIC_DISCOVERY_RANGE:-unset (default: SUBNET)}; ip -4 addr show | grep -E 'inet |^[0-9]+:'"

echo
echo "--- container node <-> container node (talker/listener, ${TIMEOUT}s) ---"
distrobox enter --root "${CONTAINER}" -- bash -lc \
    "${ROS_SETUP}; ${ENV_ARGS[*]} timeout ${TIMEOUT} ros2 run demo_nodes_cpp listener" \
    > "${LISTENER_LOG}" 2>&1 &
LISTENER_PID=$!

sleep 3   # let the listener's discovery participant come up before the talker starts
distrobox enter --root "${CONTAINER}" -- bash -lc \
    "${ROS_SETUP}; ${ENV_ARGS[*]} timeout ${TIMEOUT} ros2 run demo_nodes_cpp talker" \
    > /dev/null 2>&1 &
TALKER_PID=$!

wait "${LISTENER_PID}" 2>/dev/null || true
wait "${TALKER_PID}" 2>/dev/null || true

echo
if grep -q "I heard" "${LISTENER_LOG}"; then
    echo "PASS: listener received talker messages (DDS discovery + pub/sub working)."
    tail -5 "${LISTENER_LOG}"
    exit 0
else
    echo "FAIL: listener received nothing within ${TIMEOUT}s."
    echo "Listener output:"
    cat "${LISTENER_LOG}"
    echo
    echo "If this is the same multicast-discovery failure Gazebo Transport hit in"
    echo "Phase 5 (docs/gazebo.md), try bypassing default multicast discovery:"
    echo "  ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST ./test-network.sh ${CONTAINER}"
    echo "or pin explicit peers (the ROS analogue of Phase 5's GZ_IP fix):"
    echo "  ROS_STATIC_PEERS=127.0.0.1 ./test-network.sh ${CONTAINER}"
    exit 1
fi
