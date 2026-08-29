# Devices (Serial, Camera, CAN)

See the main README §16 (Hardware Devices) and roadmap Phase 7. Required
device classes: serial (`/dev/ttyUSB*`/`/dev/ttyACM*`), camera
(`/dev/video*`), USB, CAN.

No real hardware is available yet, so Phase 7 uses **virtual devices**
instead: the host still owns the (virtual) kernel device or interface,
exactly matching the project's host/container split (README §8) - the
container just consumes it like it would consume any real device.

## One-time host setup

The virtual camera needs a kernel module that isn't installed by
default:

```bash
sudo pacman -S v4l2loopback-dkms
```

(vcan and socat need nothing extra - `vcan` is a built-in kernel module,
`socat` is already on this host.)

## Usage

```bash
distrobox enter --root ros-jazzy -- bash containers/ros-jazzy/install-device-tools.sh
./scripts/setup-virtual-devices.sh ros-jazzy
./scripts/test-devices.sh ros-jazzy
./scripts/teardown-virtual-devices.sh ros-jazzy   # when done
```

| Device class | Mechanism | Where created | Pattern source |
|---|---|---|---|
| CAN | `vcan0` (built-in kernel module, `ip link add type vcan`) | host | `scripts/virtual-can-pattern.py` - stdlib `AF_CAN` socket, no python-can needed |
| Serial | linked PTY pair via `socat` | **inside the container** (see below) | `scripts/virtual-serial-pattern.py` - stdlib, writes a counter + CRC32 line every 0.5s |
| Camera | `v4l2loopback` kernel module, `/dev/video10` | host | `ffmpeg`'s built-in `testsrc` filter (already on this host; Omarchy even ships `v4l2-relayd` for this exact purpose, so this is the well-trodden path here, not a workaround) |

`test-devices.sh` then verifies from *inside* the container: reads a
pattern line over the serial PTY, receives one CAN frame via `candump`,
and captures one frame from `/dev/video10` via `v4l2-ctl`.

## Resolved issue - PTYs must be created inside the container

First attempt created the serial PTY pair on the host (like CAN/camera)
and it failed: the container could `readlink` the symlink fine
(`ttyV1 -> /dev/pts/8`) but opening it gave `No such file or directory`.
Confirmed cause: `/dev/pts` is a `devpts` filesystem instantiated *per
mount namespace* - PTY #8 existed in the host's instance but not the
container's, unlike real device nodes (`/dev/dri`, `/dev/video10`) or
network interfaces (`vcan0`), which are genuinely shared because this
container uses host networking and a shared `/dev`.

**Fix:** `containers/ros-jazzy/setup-virtual-serial.sh` creates the PTY
pair (and runs the pattern writer) *inside* the container instead, so
both ends live in the same `devpts` instance. `scripts/setup-virtual-devices.sh
<container>` now calls it automatically via `distrobox enter`. This is a
synthetic-testing wrinkle only - a real physical `/dev/ttyUSB0` wouldn't
have this problem, since it's a single real device node, not a devpts
pair, so it doesn't change anything about the host/container device
ownership split for real hardware.

Two follow-on issues turned up once serial creation moved into the
container, both fixed in the same script/`test-devices.sh`:

- `setup-virtual-serial.sh` runs inside a `distrobox enter -- CMD` exec
  session that exits once the script finishes. A plain `cmd &` background
  job is a child of that session and got torn down with it the moment
  `setup-virtual-devices.sh` returned, so the PTYs were already gone by
  the time `test-devices.sh` ran a moment later. Fixed with `setsid` (and
  stdin redirected from `/dev/null`) to fully detach `socat` and the
  pattern writer into their own session.
- `test-devices.sh`'s existence check used `-e` on the symlink, which
  follows it through `/dev/pts` - but from the *host's* shell, that
  resolves against the host's own `devpts` instance, where the target
  legitimately doesn't exist. Fixed by checking `-L` (symlink exists)
  instead; the real read-through-the-target check already happens inside
  the container, where it's meaningful.

## Known unknowns - flag these if something fails oddly

- **Group permissions:** if a device is visible but access is denied,
  check the container user is in the right group for it (`video` for
  `/dev/video*`, `dialout` for real serial devices - PTYs from `socat`
  are typically owned by the invoking user instead).

## Phase 7 Result — 2026-08-29

Host: Omarchy, `ros-jazzy` container.

- CAN (`vcan0`) and camera (`/dev/video10`) passed immediately, no fixes
  needed - both are genuinely host-shared (network interface / `/dev`
  node), consistent with Phase 2/6 findings.
- Serial needed two fixes before passing: creating the PTY pair inside
  the container (devpts-per-namespace, above) and `setsid`-detaching the
  background processes from the `distrobox enter` exec session that
  spawned them (both above). Confirmed working after both fixes:
  `PASS: read from container: PATTERN 000000 3ea8ddb3`.
- Final run: `./scripts/test-devices.sh ros-jazzy` → 3 passed, 0 failed.

**Verdict: passed**, all three device classes (serial, camera, CAN)
confirmed accessible from inside the container via virtual devices, no
real hardware needed for this validation.
