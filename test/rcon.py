#!/usr/bin/env python3
"""
Minimal RCON client for Minecraft servers.
No external dependencies — uses only the standard library.

Usage (standalone):
    python3 rcon.py <command>
    python3 rcon.py "say hello"

Or imported as a module:
    from rcon import rcon_command
    response = rcon_command("sktest phases")
"""
import socket
import struct
import sys
import os

HOST     = os.environ.get("RCON_HOST",     "127.0.0.1")
PORT     = int(os.environ.get("RCON_PORT", "25575"))
PASSWORD = os.environ.get("RCON_PASSWORD", "testpassword123")
TIMEOUT  = float(os.environ.get("RCON_TIMEOUT", "5"))

# RCON packet types
_AUTH        = 3
_AUTH_RESP   = 2
_COMMAND     = 2
_COMMAND_RESP = 0


def _pack(req_id: int, ptype: int, payload: str) -> bytes:
    body = payload.encode("utf-8") + b"\x00\x00"
    length = 4 + 4 + len(body)
    return struct.pack("<iii", length, req_id, ptype) + body


def _unpack(sock: socket.socket) -> tuple[int, int, str]:
    raw_len = _recv_exact(sock, 4)
    length = struct.unpack("<i", raw_len)[0]
    data   = _recv_exact(sock, length)
    req_id, ptype = struct.unpack("<ii", data[:8])
    payload = data[8:-2].decode("utf-8", errors="replace")
    return req_id, ptype, payload


def _recv_exact(sock: socket.socket, n: int) -> bytes:
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("Server closed the RCON connection.")
        buf += chunk
    return buf


def rcon_command(command: str) -> str:
    """Send one command to the server and return the response text."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(TIMEOUT)
        try:
            s.connect((HOST, PORT))
        except ConnectionRefusedError:
            raise ConnectionRefusedError(
                f"Cannot connect to RCON at {HOST}:{PORT}. "
                "Is the server running and RCON enabled?"
            )

        # Authenticate
        s.sendall(_pack(1, _AUTH, PASSWORD))
        req_id, _, _ = _unpack(s)
        if req_id == -1:
            raise PermissionError("RCON authentication failed — wrong password?")

        # Send command
        s.sendall(_pack(2, _COMMAND, command))
        _, _, response = _unpack(s)
        return response


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: python3 {sys.argv[0]} <command>")
        sys.exit(1)
    cmd = " ".join(sys.argv[1:])
    try:
        result = rcon_command(cmd)
        print(result if result else "(empty response)")
    except Exception as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        sys.exit(1)
