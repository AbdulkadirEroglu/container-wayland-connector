#!/usr/bin/env bash
# Phase 3: install ROS 2 Jazzy inside the ros-jazzy container.
# Run inside the container: distrobox enter ros-jazzy -- bash containers/ros-jazzy/install-ros.sh
set -euo pipefail

# --- locale -----------------------------------------------------------
# ROS 2 requires a UTF-8 locale. Ubuntu containers created by distrobox
# usually already have one, but this makes it explicit/reproducible.
sudo apt-get update
sudo apt-get install -y locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

# --- Ubuntu Universe repo ----------------------------------------------
# The ROS packages depend on things that live in Universe, not just Main.
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y universe

# --- ROS 2 apt repository -----------------------------------------------
# Add ROS's signing key and their apt source for noble (24.04) / Jazzy.
sudo apt-get update
sudo apt-get install -y curl
export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb"
sudo apt-get install -y /tmp/ros2-apt-source.deb

# --- Install ROS 2 Jazzy desktop ----------------------------------------
# "desktop" = ROS, RViz, common demos, tutorials. ("ros-base" would skip
# GUI tools like RViz, which we specifically want to test in Phase 4.)
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y ros-jazzy-desktop

# --- Dev tools: rosdep, colcon -------------------------------------------
sudo apt-get install -y ros-dev-tools
sudo rosdep init || true   # "already exists" is fine on re-runs
rosdep update

# --- Source ROS in future shells -----------------------------------------
# ~/.bashrc is shared with the host and every other container via
# distrobox's HOME integration, so this must be guarded: the path only
# exists inside this specific container's filesystem.
if ! grep -q "ros/jazzy/setup.bash" "${HOME}/.bashrc"; then
    echo '[[ -r /opt/ros/jazzy/setup.bash ]] && source /opt/ros/jazzy/setup.bash' >> "${HOME}/.bashrc"
fi

echo
echo "ROS 2 Jazzy installed."
echo "Open a new shell (or 'source /opt/ros/jazzy/setup.bash') then verify with:"
echo "  ros2 --version"
echo "  ros2 run demo_nodes_cpp talker"
