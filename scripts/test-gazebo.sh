#!/usr/bin/env bash
# Phase 5 acceptance check: launch Gazebo with a built-in test world
# inside a distrobox container and confirm it renders on the host
# compositor.
#
# Usage: ./test-gazebo.sh <container-name> [world]
#
# Debug level controls (env vars, all optional):
#   GZ_VERBOSITY   gz sim's own -v level, 0-4 (default: 1). 4 is very
#                  noisy (per-frame Dbg spam) - use it only while actively
#                  diagnosing a startup/rendering issue, not for routine runs.
#   QT_LOGGING_RULES  Qt's own debug categories, e.g. "qt.qpa.*=true" to
#                  trace platform-plugin (xcb/wayland) selection and window
#                  creation - useful when the GUI process starts but no
#                  window appears (the Ogre2/Wayland issue below).
#
# If the GUI crashes creating its render window (the same Ogre/GLX-vs-
# Wayland issue documented for RViz2 in docs/wayland.md), re-run with:
#   QT_QPA_PLATFORM=xcb ./test-gazebo.sh <container-name> [world]
#
# GZ_IP defaults to 127.0.0.1: on this host, Gazebo Transport's default
# multicast peer discovery fails to connect the server and GUI subprocesses
# (each loads/runs fine standalone, but the GUI never sees the server) -
# see docs/gazebo.md. Override GZ_IP if your container's networking differs.
set -euo pipefail

CONTAINER="${1:?usage: test-gazebo.sh <container-name> [world]}"
WORLD="${2:-shapes.sdf}"
VERBOSITY="${GZ_VERBOSITY:-1}"
GZ_IP_VAL="${GZ_IP:-127.0.0.1}"

echo "Launching 'gz sim -v ${VERBOSITY} ${WORLD}' inside '${CONTAINER}'..."
# --root: this host's Docker daemon is rootful-only (see docs/troubleshooting.md).
# `gz` lives under /opt/ros/jazzy/opt/gz_tools_vendor/bin, only on PATH once
# /opt/ros/jazzy/setup.bash is sourced. install-ros.sh sources it from
# ~/.bashrc, but ~/.bashrc's own interactive-shell guard skips that under a
# non-interactive `bash -lc`, so source it explicitly here instead.
ROS_SETUP="[ -r /opt/ros/jazzy/setup.bash ] && . /opt/ros/jazzy/setup.bash"
ENV_ARGS=("GZ_IP='${GZ_IP_VAL}'")
[ -n "${QT_QPA_PLATFORM:-}" ] && ENV_ARGS+=("QT_QPA_PLATFORM='${QT_QPA_PLATFORM}'")
[ -n "${QT_LOGGING_RULES:-}" ] && ENV_ARGS+=("QT_LOGGING_RULES='${QT_LOGGING_RULES}'")

distrobox enter --root "${CONTAINER}" -- bash -lc "${ROS_SETUP}; ${ENV_ARGS[*]} gz sim -v ${VERBOSITY} '${WORLD}'"
