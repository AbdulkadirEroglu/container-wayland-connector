#!/usr/bin/env python3
"""Send an incrementing pattern of CAN frames on a SocketCAN interface.

Used to test CAN passthrough into a container without real CAN hardware
(Phase 7, docs/devices.md). Pure stdlib: Python's socket module supports
SocketCAN (AF_CAN/SOCK_RAW) directly on Linux, no python-can needed.
Sending on an already-up interface doesn't require root (only creating
the interface itself does - see setup-virtual-devices.sh).

Usage: virtual-can-pattern.py [interface] [interval-seconds]
"""
import socket
import struct
import sys
import time

CAN_ID = 0x123


def main() -> None:
    iface = sys.argv[1] if len(sys.argv) > 1 else "vcan0"
    interval = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5

    sock = socket.socket(socket.AF_CAN, socket.SOCK_RAW, socket.CAN_RAW)
    sock.bind((iface,))

    counter = 0
    try:
        while True:
            data = struct.pack("<I4x", counter)  # 8-byte payload, counter in first 4 bytes
            frame = struct.pack("<IB3x8s", CAN_ID, len(data), data)
            sock.send(frame)
            counter = (counter + 1) % (2**32)
            time.sleep(interval)
    finally:
        sock.close()


if __name__ == "__main__":
    main()
