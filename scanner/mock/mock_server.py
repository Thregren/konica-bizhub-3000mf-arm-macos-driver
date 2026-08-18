#!/usr/bin/env python3
"""Minimal mock of a Brother ML13 scanner on TCP port 54921.

Used to exercise the native protocol library without a physical printer.
It understands the ESC .. 0x80 packet framing, replies to the 'I' lease
request and streams synthetic page data for the 'X' scan request.
"""

import argparse
import socket
import struct

READY = b"+OK 200\r\n"
OFFER = b"\x00\x1d\x00" + b"300,300,1,210,2480,297,3507,\x00"


def read_packet(conn: socket.socket) -> bytes:
    buf = bytearray()
    while True:
        chunk = conn.recv(4096)
        if not chunk:
            break
        buf.extend(chunk)
        if buf and buf[-1] == 0x80:
            break
    return bytes(buf)


def parse_area(packet: bytes) -> tuple[int, int]:
    """Return (width, height) parsed from the A=x,y,w,h field."""
    width, height = 2480, 3507
    for line in packet.split(b"\n"):
        if line.startswith(b"A="):
            fields = line[2:].decode("ascii", "replace").split(",")
            if len(fields) == 4:
                width = int(fields[2])
                height = int(fields[3])
    return width, height


def stream_pages(conn: socket.socket, width: int, height: int, pages: int) -> None:
    total = width * height
    payload = bytearray()
    # Cheap synthetic image: horizontal gradient plus a page marker column.
    row = bytes((x % 256 for x in range(width)))
    payload.extend(row * height)

    chunk_size = 65535  # payload length is a 16-bit little-endian value
    for page in range(pages):
        offset = 0
        while offset < total:
            size = min(chunk_size, total - offset)
            header = bytearray(12)
            struct.pack_into("<H", header, 10, size)
            conn.sendall(header)
            conn.sendall(payload[offset : offset + size])
            offset += size
        conn.sendall(b"\x82")
        conn.sendall(b"\x00" * 10)  # per-page footer
    conn.sendall(b"\x80")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=54921)
    parser.add_argument("--pages", type=int, default=2)
    args = parser.parse_args()

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", args.port))
        server.listen(4)
        print(f"mock scanner listening on 127.0.0.1:{args.port}", flush=True)

        while True:
            conn, addr = server.accept()
            print(f"connection from {addr}", flush=True)
            with conn:
                conn.sendall(READY)
                while True:
                    packet = read_packet(conn)
                    if not packet:
                        break
                    if b"\x1bI" in packet:
                        print("  lease request", flush=True)
                        conn.sendall(OFFER)
                    elif b"\x1bX" in packet:
                        width, height = parse_area(packet)
                        print(
                            f"  scan request {width}x{height}, "
                            f"{args.pages} page(s)",
                            flush=True,
                        )
                        stream_pages(conn, width, height, args.pages)
                    elif b"\x1bR" in packet:
                        print("  cancel request", flush=True)


if __name__ == "__main__":
    main()
