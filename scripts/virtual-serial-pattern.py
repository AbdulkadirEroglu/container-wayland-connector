#!/usr/bin/env python3
"""Write an incrementing, checksummed pattern into a serial device path.

Used with setup-virtual-devices.sh's virtual PTY pair to test serial
device passthrough into a container without real hardware (Phase 7,
docs/devices.md). Pure stdlib - no pyserial needed, since a PTY is just
a byte stream and doesn't need real baud-rate negotiation.

Usage: virtual-serial-pattern.py <serial-path> [interval-seconds]
"""
import os
import sys
import time
import zlib


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(f"usage: {sys.argv[0]} <serial-path> [interval-seconds]")
    path = sys.argv[1]
    interval = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5

    fd = os.open(path, os.O_WRONLY)
    try:
        counter = 0
        while True:
            payload = f"PATTERN {counter:06d}".encode()
            crc = zlib.crc32(payload)
            os.write(fd, payload + f" {crc:08x}\n".encode())
            counter += 1
            time.sleep(interval)
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()
