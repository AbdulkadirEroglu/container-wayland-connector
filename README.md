<div align="center">

# 🤖 Containerized Robotics Desktop Environment

**Run ROS · Gazebo · RViz on any Linux host — without being held hostage by Ubuntu.**

![Status](https://img.shields.io/badge/status-prototyping-yellow)
![Host](https://img.shields.io/badge/host-Omarchy%20%7C%20Arch%20%7C%20NixOS%20%7C%20Fedora-blue)
![Container](https://img.shields.io/badge/container-Ubuntu%2024.04-E95420)
![Runtime](https://img.shields.io/badge/runtime-Distrobox-informational)
![Display](https://img.shields.io/badge/display-Wayland-1793D1)
![GPU](https://img.shields.io/badge/GPU-NVIDIA%20%7C%20AMD-76B900)

</div>

---

```text
   ┌─────────────────────────── HOST ───────────────────────────┐
   │   kernel · GPU driver · Wayland compositor · PipeWire       │
   │   NetworkManager · BlueZ · udev · USB / serial / cameras    │
   │                                                              │
   │        ┌──────────────── UBUNTU CONTAINER ────────────┐     │
   │        │   ROS 2 · Gazebo · RViz · MoveIt              │     │
   │        │   rosdep · colcon · vendor SDKs               │     │
   │        └───────────────────────┬────────────────────────┘   │
   │                                │ Wayland socket / GPU        │
   │                                ▼                             │
   │                     🪟  native host window                  │
   └──────────────────────────────────────────────────────────────┘
```

<div align="center">

**No VMs. No VNC. No nested desktops. Just a Wayland socket and a container.**

</div>

---

## ✨ Why This Exists

> **The host operating system should not be chosen only because ROS officially supports Ubuntu.**

ROS, Gazebo, RViz, vendor SDKs, and older CUDA toolchains often assume a specific Ubuntu release — making distros like **Arch**, **Omarchy**, **NixOS**, and **Fedora** harder to adopt as a daily-driver workstation.

Instead of rebuilding the entire ROS ecosystem for every distro, this project draws one clean line:

| 🖥️ Host owns | 📦 Container owns |
|---|---|
| Kernel & GPU driver | ROS 2 |
| Wayland compositor | Gazebo |
| PipeWire (audio) | RViz / MoveIt |
| NetworkManager / BlueZ | rosdep / colcon |
| USB, serial, cameras | Vendor Ubuntu SDKs |

GUI apps still do their own rendering (OpenGL/Vulkan) — the container just hands the finished frame to the **host's** Wayland compositor over the shared socket:

```text
container app → OpenGL/Vulkan → host GPU → Wayland socket → host compositor → 🪟
```

> 📖 The full design rationale, architecture diagrams, and 45-section deep dive live in
> **[`containerized-robotics-desktop-README.md`](containerized-robotics-desktop-README.md)**.

---

## 🗂️ Repository Layout

```text
container-wayland-connector/
├── containers/
│   └── ros-jazzy/              🐢 Ubuntu 24.04 + ROS 2 Jazzy environment
│       ├── create.sh
│       ├── setup.sh
│       └── packages.txt
│
├── scripts/                    🧪 host checks & acceptance tests
│   ├── check-host.sh
│   ├── check-gpu.sh
│   ├── export-apps.sh
│   ├── test-wayland.sh
│   ├── test-audio.sh
│   ├── test-network.sh
│   └── test-devices.sh
│
├── host/                       🔧 host-side config (udev rules, etc.)
└── docs/                       📚 architecture · nvidia · wayland · ros-networking · troubleshooting
```

---

## 🚦 Status

```text
[■■■■■□□□□□] Phase 0-2 done — Wayland + NVIDIA GPU validated in-container
```

| Phase | Status |
|---|---|
| 0 — Basic container | ✅ done |
| 1 — Wayland | ✅ done — `glxgears` renders on host Hyprland, correct theming/window rules |
| 2 — GPU (NVIDIA) | ✅ done — hardware OpenGL + Vulkan confirmed, no driver ABI mismatch |
| 3 — ROS | ✅ done — ROS 2 Jazzy installed, `ros2 doctor` all checks pass, talker/listener DDS confirmed |
| 4 — RViz | ✅ done — needs `QT_QPA_PLATFORM=xcb` (see [known issue](docs/wayland.md#known-issue-ogre-based-apps-rviz2-need-qt_qpa_platformxcb)) |
| 5 — Gazebo | ⬜ |
| 6 — Networking (DDS) | ⬜ |
| 7 — Devices | ⬜ |
| 8 — Desktop integration | ⬜ |

See [`docs/wayland.md`](docs/wayland.md) and [`docs/nvidia.md`](docs/nvidia.md) for detailed results.

---

## 🚀 Quick Start

```bash
# 1. Confirm the host is ready (distrobox, Wayland, GPU)
./scripts/check-host.sh
./scripts/check-gpu.sh

# 2. Create the first environment
./containers/ros-jazzy/create.sh

# 3. Install base packages inside it
distrobox enter ros-jazzy -- bash containers/ros-jazzy/setup.sh
```

---

<div align="center">

*Keep hardware and desktop responsibilities on the host — move distribution-sensitive userspace into reproducible containers.*

</div>
