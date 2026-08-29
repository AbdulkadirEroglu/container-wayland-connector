#!/usr/bin/env bash
# Phase 5: install Gazebo Harmonic inside the ros-jazzy container.
# Run inside the container: distrobox enter --root ros-jazzy -- bash containers/ros-jazzy/install-gazebo.sh
# (drop --root if your host's Docker isn't rootful-only; see docs/troubleshooting.md)
#
# Requires ROS 2 Jazzy to already be installed (containers/ros-jazzy/install-ros.sh),
# since ros_gz bridges against it.
set -euo pipefail

if ! dpkg -s ros-jazzy-desktop >/dev/null 2>&1; then
    echo "ROS 2 Jazzy not found. Run install-ros.sh first." >&2
    exit 1
fi

# --- Gazebo Harmonic + ros_gz bridge -------------------------------------
# ros-jazzy-ros-gz is the official metapackage pairing ROS 2 Jazzy with its
# associated Gazebo release (Harmonic) and the ros_gz bridge/plugins.
sudo apt-get update
sudo apt-get install -y ros-jazzy-ros-gz

echo
echo "Gazebo Harmonic installed."
echo "Verify with:"
echo "  gz sim --version"
echo "  gz sim -v 4 shapes.sdf"
echo
echo "If the GUI fails to create its render window under Wayland (Ogre2/GLX"
echo "vs. a native Wayland surface), see the known RViz issue in"
echo "docs/wayland.md and try: QT_QPA_PLATFORM=xcb gz sim shapes.sdf"
