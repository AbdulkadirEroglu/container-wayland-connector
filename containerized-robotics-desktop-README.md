# Containerized Robotics Desktop Environment

> A host-agnostic approach for running ROS, Gazebo, RViz, and other distribution-sensitive GUI development stacks inside Ubuntu containers while keeping the desktop, compositor, GPU driver, and hardware integration on the host.

## 1. Project Motivation

This project exists to remove a recurring limitation from Linux workstation choices:

> **The host operating system should not be chosen only because ROS officially supports Ubuntu.**

ROS, Gazebo, RViz, vendor SDKs, older CUDA toolchains, and robotics packages often assume a specific Ubuntu release. This makes otherwise attractive distributions such as Arch Linux, Omarchy, NixOS, Fedora, and immutable/atomic distributions harder to adopt as a primary workstation.

Rebuilding or repackaging the entire ROS ecosystem for every Linux distribution is not a good use of time.

The preferred solution is to separate:

```text
Host operating system
        from
Development userspace
```

The host should provide:

```text
kernel
drivers
GPU
Wayland compositor
audio
networking
USB/hardware access
input devices
```

while Ubuntu containers provide:

```text
ROS
Gazebo
RViz
MoveIt
rosdep
colcon
project dependencies
vendor libraries
distribution-specific packages
```

This allows the desktop operating system to be chosen based on desktop experience, maintainability, hardware support, and personal preference rather than ROS package availability.

## 2. High-Level Architecture

```text
┌────────────────────────────────────────────────────────────┐
│                         HOST OS                            │
│                                                            │
│  Omarchy / Arch / NixOS / Fedora / Ubuntu / ...           │
│                                                            │
│  Linux kernel                                              │
│  NVIDIA / AMD driver                                       │
│  Hyprland / other Wayland compositor                       │
│  Wayland                                                   │
│  PipeWire                                                  │
│  NetworkManager                                            │
│  BlueZ                                                     │
│  udev                                                      │
│  USB / serial / camera devices                             │
│                                                            │
│         ┌───────────────────────────────────────┐           │
│         │          Ubuntu Container             │           │
│         │                                       │           │
│         │ ROS 2                                 │           │
│         │ Gazebo                                │           │
│         │ RViz                                  │           │
│         │ MoveIt                                │           │
│         │ rosdep                                │           │
│         │ colcon                                │           │
│         │ project workspace                     │           │
│         │ Ubuntu-only/vendor dependencies       │           │
│         └───────────────────┬───────────────────┘           │
│                             │                               │
│                    Wayland / GPU / audio                    │
│                    network / devices                        │
│                             │                               │
│                             ▼                               │
│                     Native host window                      │
└────────────────────────────────────────────────────────────┘
```

The target user experience is that applications such as RViz or Gazebo feel like normal host applications even though their userspace runs inside Ubuntu.

## 3. Important Design Principle

This is **not** a virtual machine desktop.

Avoid using a full Ubuntu VM, nested desktop, VNC, or RDP for normal local use.

Individual applications should connect directly to host services wherever practical.

Example:

```text
Ubuntu container
    │
    ├── RViz
    │    ↓
    │  Ogre
    │    ↓
    │ OpenGL/Vulkan
    │    ↓
    │ host GPU devices
    │
    └─────────────→ host Wayland compositor
                         ↓
                      display
```

The application still performs its rendering. The host provides the kernel driver, physical GPU access, display compositor, and final presentation.

## 4. Why Wayland Helps

Wayland makes this architecture especially attractive.

For a local container, the container can be given access to the host Wayland socket:

```text
$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY
```

A GUI application inside the container can then create a normal surface on the host compositor.

Conceptually:

```text
container application
        ↓
Wayland socket
        ↓
host compositor
        ↓
normal desktop window
```

This avoids requiring a complete graphical desktop inside the container.

## 5. Rendering Model

The host does **not** render the application's scene on behalf of the application.

For RViz, Gazebo, Qt, GTK, etc.:

```text
Application
    ↓
OpenGL / Vulkan
    ↓
GPU
    ↓
rendered buffer
    ↓
Wayland
    ↓
host compositor
```

With containers:

```text
Ubuntu container process
        ↓
OpenGL / Vulkan userspace
        ↓
host GPU device
        ↓
host kernel driver
        ↓
Wayland surface
        ↓
host compositor
```

The goal is therefore to expose the host GPU correctly rather than remotely forwarding rendered video.

## 6. Container Technology

The preferred initial technology is **Distrobox**.

Distrobox is attractive because it is designed for highly integrated development containers. It can use Docker or Podman underneath while integrating host resources such as:

- HOME
- Wayland
- X11
- audio
- devices
- user identity
- networking
- desktop applications

This project should initially build on Distrobox rather than recreate all host integration manually.

Lower-level Docker/Podman implementations can be added later if stronger isolation or custom behavior becomes necessary.

## 7. NVIDIA Support

NVIDIA is a critical requirement.

The host owns:

```text
kernel module
GPU device
NVIDIA driver
```

The container must not blindly install a conflicting NVIDIA driver stack.

Potential failure:

```text
host:
NVIDIA driver 590

container:
NVIDIA userspace 580

→ driver/library mismatch
```

The intended model is:

```text
Host NVIDIA driver
        ↓
container-compatible userspace access
        ↓
container application
```

Distrobox NVIDIA integration should be the first approach. NVIDIA Container Toolkit / CDI may also be considered for lower-level implementations.

## 8. Host Responsibilities

The host should own hardware and desktop responsibilities.

```text
Kernel
GPU driver
Wayland compositor
PipeWire
NetworkManager
Bluetooth / BlueZ
udev rules
USB permissions
input devices
display configuration
container runtime
Distrobox
```

Examples of host-side resources:

```text
/dev/dri/*
/dev/nvidia*
/dev/ttyUSB*
/dev/ttyACM*
/dev/video*
CAN interfaces
USB devices
```

Host-level device rules should stay on the host.

Examples:

```text
udev rules
dialout membership
video/render group permissions
kernel modules
CAN setup
USB permissions
```

## 9. Container Responsibilities

The Ubuntu container should own distribution-specific development dependencies:

```text
ROS 2
Gazebo
RViz
MoveIt
rosdep
colcon
CMake dependencies
ROS packages
Python packages
project libraries
vendor Ubuntu SDKs
specific compiler versions
```

The host should ideally remain free from most ROS dependencies.

## 10. ROS Strategy

Do **not** port ROS to the host distribution unless there is a compelling reason.

Use the Ubuntu release officially associated with the required ROS distribution.

Examples:

```text
Ubuntu 24.04
ROS 2 Jazzy
Gazebo Harmonic
```

and:

```text
Ubuntu 26.04
ROS 2 Lyrical
Gazebo Jetty
```

This preserves the official package ecosystem:

```bash
apt
rosdep
colcon
```

and avoids maintaining custom Arch/Nix/Fedora ROS packaging.

## 11. Multiple ROS Environments

A major benefit of the container approach is that multiple ROS generations can coexist cleanly.

```text
containers/
├── ros-jazzy/
│   ├── Ubuntu 24.04
│   ├── ROS 2 Jazzy
│   └── Gazebo Harmonic
│
├── ros-lyrical/
│   ├── Ubuntu 26.04
│   ├── ROS 2 Lyrical
│   └── Gazebo Jetty
│
└── ros-rolling/
    └── ...
```

Projects can select the environment they require.

## 12. Example Workflow

Example container creation:

```bash
distrobox create     --name ros-jazzy     --image ubuntu:24.04     --nvidia
```

Enter:

```bash
distrobox enter ros-jazzy
```

Inside:

```bash
source /opt/ros/jazzy/setup.bash
cd ~/workspace
colcon build
```

Then:

```bash
rviz2
```

or:

```bash
gz sim
```

The target is for the application window to appear directly on the host Wayland desktop.

## 13. Desktop Application Integration

Containerized GUI applications should eventually be launchable from the normal host application launcher.

Desired launcher UX:

```text
Firefox
Terminal
Visual Studio Code
RViz
Gazebo
Steam
...
```

Target flow:

```text
Host launcher
     ↓
RViz
     ↓
ros-jazzy container
     ↓
rviz2
     ↓
host Wayland window
```

The user should not need to manually enter the container first.

## 14. IDE Strategy

### Option A — IDE inside the container

```text
VS Code
   ↓
Ubuntu container
   ↓
ROS workspace
```

Advantages:

- terminal already has ROS environment,
- extensions see Ubuntu libraries,
- compiler/tooling match the project,
- fewer environment mismatches.

The GUI still appears on the host.

### Option B — Host IDE + container toolchain

Possible later through remote/container integrations or language servers/build commands inside Distrobox.

Start with whichever proves simpler and more reliable.

## 15. Networking and ROS DDS

ROS 2 relies heavily on DDS discovery.

Potential problems with conventional containers include:

```text
bridge networking
multicast
UDP discovery
host/container isolation
robot discovery
```

The initial architecture should keep networking as close to the host as possible.

Tests must include:

```text
container node ↔ container node
container node ↔ host
container node ↔ robot on LAN
DDS multicast discovery
ROS topics/services/actions
```

Networking success is a core acceptance requirement.

## 16. Hardware Devices

Robotics development often depends on:

```text
/dev/ttyUSB0
/dev/ttyACM0
/dev/video0
RealSense cameras
LiDAR
CAN adapters
serial controllers
USB devices
joysticks
microcontrollers
```

The preferred responsibility split is:

```text
Host:
    kernel driver
    udev
    permissions
    physical device

Container:
    userspace SDK
    ROS driver
    application
```

Avoid privileged containers where narrower device access works.

## 17. Audio

PipeWire should remain on the host.

Containerized applications that need audio should connect to host audio services rather than duplicating the full audio stack inside the container.

## 18. Clipboard and Input

The desired desktop experience includes normal:

- keyboard input,
- mouse input,
- clipboard,
- file dialogs,
- notifications where practical.

Wayland security constraints should be respected. Avoid broad unsafe permissions merely to imitate host behavior.

## 19. Waypipe

Waypipe is useful, but it should **not** be the default for a local container.

For the same machine:

```text
direct Wayland socket
```

is simpler.

Waypipe becomes more interesting for:

```text
remote development machine
SSH host
GPU server
VM
strongly isolated namespace
remote robotics workstation
```

Potential future topology:

```text
remote Ubuntu ROS machine
        ↓
waypipe
        ↓
local Hyprland
```

## 20. Host Distribution Independence

The project should intentionally avoid becoming Omarchy-specific.

Omarchy is currently a strong candidate host because it provides:

- polished Hyprland setup,
- Quickshell,
- strong theme integration,
- development tooling,
- Arch ecosystem,
- current graphics stack.

But the architecture should also work with:

```text
NixOS
Arch
Fedora
Ubuntu
other Wayland distributions
```

The development environment should survive future host changes.

## 21. Omarchy Use Case

One motivating scenario is:

```text
Omarchy host
│
├── Hyprland
├── Quickshell
├── NVIDIA
├── CUDA
├── Docker / Podman
├── normal development applications
│
└── Ubuntu ROS containers
      ├── ROS
      ├── Gazebo
      └── RViz
```

This would allow using the full Omarchy desktop without recreating its extensive UI/theme integration on Ubuntu.

## 22. NixOS Use Case

The same architecture addresses the NixOS problem:

```text
NixOS host
        +
Ubuntu ROS container
```

Instead of rebuilding ROS packages for Nix, use the official Ubuntu stack inside the container.

## 23. Other Potential Uses

Although ROS is the initial motivation, the model is more general.

Possible workloads:

```text
vendor Ubuntu-only SDK
old CUDA project
legacy compiler
specific GCC version
old Python environment
embedded toolchains
special Gazebo release
robot vendor software
old Qt application
binary-only proprietary SDK
```

Each can get its own development container.

## 24. Proposed Repository Direction

```text
containerized-dev/
├── README.md
├── LICENSE
│
├── containers/
│   ├── ros-jazzy/
│   │   ├── create.sh
│   │   ├── setup.sh
│   │   └── packages.txt
│   │
│   ├── ros-lyrical/
│   │   ├── create.sh
│   │   ├── setup.sh
│   │   └── packages.txt
│   │
│   └── ...
│
├── scripts/
│   ├── check-host.sh
│   ├── check-gpu.sh
│   ├── export-apps.sh
│   ├── test-wayland.sh
│   ├── test-audio.sh
│   ├── test-network.sh
│   └── test-devices.sh
│
├── host/
│   ├── udev/
│   └── README.md
│
└── docs/
    ├── architecture.md
    ├── nvidia.md
    ├── wayland.md
    ├── ros-networking.md
    └── troubleshooting.md
```

Do not over-engineer the repository before the first prototype works.

## 25. Reproducibility

The environment should eventually be reproducible from scripts.

Desired flow:

```bash
git clone <repo>
cd <repo>
./containers/ros-jazzy/create.sh
```

Expected result:

```text
Ubuntu 24.04 container
ROS Jazzy installed
Gazebo installed
RViz installed
workspace ready
GPU available
Wayland available
```

Avoid undocumented manual container modifications.

## 26. Persistent Project Data

Project source code should not be trapped inside disposable container storage.

Preferred approach:

```text
host filesystem
      ↓
shared HOME/workspace
      ↓
container
```

Example:

```text
~/Projects/robotics/
```

The container should contain dependencies, not become the only copy of project data.

## 27. Security Philosophy

Distrobox intentionally favors integration over strict isolation.

This project is primarily a **development environment abstraction**, not a sandbox security boundary.

Avoid unnecessarily exposing:

```text
full /dev
privileged mode
host root filesystem
all capabilities
```

when narrower permissions work.

## 28. Prototype Acceptance Tests

### Graphics

```text
[ ] Wayland GUI application launches from container
[ ] RViz launches
[ ] RViz uses hardware acceleration
[ ] Gazebo launches
[ ] Gazebo uses hardware acceleration
[ ] Qt application behaves normally
[ ] window resize/fullscreen works
[ ] no major input issues
```

### NVIDIA

```text
[ ] nvidia-smi works where appropriate
[ ] OpenGL hardware acceleration works
[ ] Vulkan works if required
[ ] CUDA is available when required
[ ] no host/container driver ABI mismatch
```

### ROS

```text
[ ] ros2 CLI works
[ ] colcon builds
[ ] rosdep works
[ ] container nodes discover each other
[ ] ROS topics work
[ ] ROS services work
[ ] DDS multicast works
[ ] LAN robot discovery works
```

### Devices

```text
[ ] /dev/ttyUSB device accessible
[ ] /dev/ttyACM device accessible
[ ] camera accessible
[ ] joystick/input devices accessible
[ ] USB hotplug behaves correctly
```

### Desktop integration

```text
[ ] RViz launchable from host launcher
[ ] Gazebo launchable from host launcher
[ ] clipboard works
[ ] audio works where needed
[ ] files are accessible
[ ] application icons/desktops behave normally
```

## 29. First Prototype

The first prototype should intentionally be small.

Suggested first experiment:

```text
Existing Ubuntu host
        +
Distrobox
        +
Ubuntu 24.04 container
        +
simple Wayland GUI
```

Then add:

```text
NVIDIA
↓
RViz
↓
Gazebo
↓
ROS networking
↓
USB devices
```

Testing the architecture first on Ubuntu is useful because it separates container integration problems from Arch/Omarchy host problems.

## 30. Development Sequence

### Phase 0 — Basic container

```text
create Ubuntu container
enter container
install normal CLI applications
verify shared filesystem
```

### Phase 1 — Wayland

```text
launch simple Wayland/Qt GUI
verify host compositor integration
```

### Phase 2 — GPU

```text
verify OpenGL
verify Vulkan
verify NVIDIA integration
```

### Phase 3 — ROS

```text
install ROS
run demo nodes
verify rosdep/colcon
```

### Phase 4 — RViz

```text
launch RViz
verify GPU acceleration
verify interaction
```

### Phase 5 — Gazebo

```text
launch Gazebo
load test world
verify rendering
```

### Phase 6 — Networking

```text
DDS discovery
LAN robot
host/container communication
```

### Phase 7 — Devices

```text
serial
camera
USB
CAN
```

### Phase 8 — Desktop Integration

```text
export desktop entries
launcher integration
IDE integration
```

## 31. Known Risk Areas

These require careful testing:

- NVIDIA userspace / kernel ABI
- Vulkan ICD and loader configuration
- Gazebo rendering
- RViz / Ogre behavior
- Wayland-only applications
- XWayland fallback
- ROS DDS discovery and multicast
- USB permissions
- D-Bus integration
- PipeWire sockets and permissions

## 32. Things to Avoid Initially

Do not begin by writing a custom GUI transport protocol.

Do not begin by creating a custom Wayland proxy.

Do not port the full ROS ecosystem to Arch.

Do not install ROS packages directly on the Omarchy host as the primary solution.

Do not use a full VM unless container graphics integration proves inadequate.

Do not solve every possible host distribution in v0.1.

Use existing building blocks first:

```text
Distrobox
Docker/Podman
Wayland
PipeWire
NVIDIA Container Toolkit where necessary
```

Custom components should be introduced only after an actual limitation is identified.

## 33. Potential Future Wrapper

Once the concept works, the project could provide a small management CLI.

Example:

```bash
robot-env create jazzy
robot-env enter jazzy
robot-env run jazzy rviz2
robot-env run jazzy gz sim
robot-env export jazzy rviz2
robot-env test jazzy
robot-env remove jazzy
```

This wrapper could hide Distrobox implementation details.

## 34. Possible Desktop Integration

For an Omarchy/Hyprland desktop, a future integration could expose entries such as:

```text
RViz — ROS Jazzy
Gazebo — ROS Jazzy
Terminal — ROS Jazzy
VS Code — ROS Jazzy

RViz — ROS Lyrical
Gazebo — ROS Lyrical
```

This makes multiple environments explicit while preserving native launcher behavior.

## 35. Environment Identification

Applications and shells should clearly identify their active environment.

Example prompt:

```text
[ros-jazzy] user@host
```

or:

```text
ROS: Jazzy | Ubuntu 24.04
```

This prevents accidentally installing packages into the wrong environment.

## 36. Host Package Philosophy

The host should contain tools that are inherently host-level or broadly useful:

```text
GPU driver
container runtime
Distrobox
Git
terminal
editor if desired
browser
desktop applications
system monitoring
```

ROS-specific dependency trees should remain inside containers.

## 37. CUDA Strategy

CUDA requires a separate decision depending on the project.

Some AI workloads may run directly on the host because Arch/Omarchy provides a current CUDA stack.

Other projects may require a specific CUDA version and should be containerized.

Therefore:

```text
Current/general AI workload
        → host may be acceptable

Version-locked project
        → container
```

The project should not impose one CUDA model globally.

## 38. Container Images

Prefer well-defined base images:

```text
ubuntu:24.04
ubuntu:26.04
```

Avoid large opaque third-party images unless they provide clear value.

The setup scripts should define what gets installed.

## 39. Versioning

Each environment should be versionable.

Example:

```text
ros-jazzy-v1
ros-jazzy-v2
```

Breaking environment upgrades should not silently destroy a working robotics toolchain.

## 40. Backup / Recovery

Containers should be disposable.

Important data must remain outside the container or be backed up.

If an environment becomes broken:

```text
delete container
        ↓
recreate from repository
        ↓
continue working
```

## 41. Success Criteria

The project succeeds when switching host distributions no longer requires rebuilding the robotics development environment.

Ideal scenario:

```text
Day 1:
Ubuntu host
+
ros-jazzy container

Later:
Omarchy host
+
same ros-jazzy environment

Later again:
NixOS host
+
same ros-jazzy environment
```

From the developer's perspective:

```text
ros2
RViz
Gazebo
hardware
projects
```

continue working with minimal changes.

## 42. Long-Term Vision

The workstation becomes:

```text
HOST
    stable hardware + desktop interface

ENVIRONMENTS
    project-specific userspaces
```

Example:

```text
Host: Omarchy

Environments:
    ros-jazzy
    ros-lyrical
    cuda-12-legacy
    embedded-arm
    vendor-sdk
    old-python-project
```

This decouples the preferred desktop from software ecosystem constraints.

## 43. Current Working Decision

The current direction is:

1. Continue experimenting with **Omarchy** separately.
2. Do **not** immediately migrate the primary machine.
3. Prototype the containerized GUI/ROS architecture first.
4. Start testing on the current Ubuntu installation.
5. Use **Distrobox + Ubuntu containers** as the first implementation.
6. Use direct **Wayland socket integration** for local GUI applications.
7. Keep GPU drivers and hardware management on the host.
8. Keep ROS/Gazebo/RViz inside Ubuntu userspace.
9. Test NVIDIA, RViz, Gazebo, DDS networking, and USB devices thoroughly.
10. If these pass, the largest practical reason to remain on Ubuntu as the host largely disappears.

## 44. First Concrete Task

Create the smallest possible proof of concept:

```text
Ubuntu host
+
Distrobox
+
Ubuntu 24.04 container
+
GPU-enabled Wayland GUI application
```

Then validate:

```text
Wayland
OpenGL
Vulkan
NVIDIA
```

before installing ROS.

After graphics works:

```text
ROS Jazzy
→ RViz
→ Gazebo
→ DDS
→ USB/camera
```

## 45. Guiding Principle

Do not solve distribution incompatibility by forcing every application onto the host.

Instead:

> **Keep hardware and desktop responsibilities on the host, and move distribution-sensitive userspace into reproducible containers.**

The host operating system should be chosen because it is the best host.

The ROS operating system should be chosen because it is the best ROS userspace.

They do not need to be the same Linux distribution.
