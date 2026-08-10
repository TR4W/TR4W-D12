#!/usr/bin/env python3
"""
tciclient -- a hand-driven TCI client for TR4W's server.

WHY THIS EXISTS.  WSJT-X always addresses trx 0 -- that is documented in the
reference server and is why a second receiver cannot be tested with it.  This
client lets you send any command to any receiver by hand:

    > vfo:1,0;              read radio 2's frequency
    > vfo:1,0,7040000;      move radio 2
    > trx:1,true;           key radio 2
    > split_enable:0,true;

It also prints everything the server sends, so running it ALONGSIDE WSJT-X
shows whether a change made by one client is broadcast to the other.

NO DEPENDENCIES.  RFC 6455 is implemented here over a raw socket rather than
pulling in a websockets library: the framing is fifty lines, TR4W's own server
is the thing being tested, and a second implementation of the same spec is a
better check than the same library on both ends.

SELF-TEST.  --selftest runs the client against a minimal server in-process and
verifies the handshake and both directions, with no radio and no TR4W.  Run it
before trusting a session; three tools tonight reached a live transmitter with
bugs that a ten-second offline check would have caught.

    python tciclient.py --selftest
    python tciclient.py --port 50001
"""

import argparse
import base64
import hashlib
import os
import socket
import struct
import sys
import threading
import time

WS_GUID = b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def accept_key(client_key: bytes) -> str:
    return base64.b64encode(hashlib.sha1(client_key + WS_GUID).digest()).decode()


def handshake(sock, host, port, resource="/"):
    key = base64.b64encode(os.urandom(16))
    req = (
        f"GET {resource} HTTP/1.1\r\n"
        f"Host: {host}:{port}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key.decode()}\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "\r\n"
    ).encode()
    sock.sendall(req)

    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            raise RuntimeError("server closed during handshake")
        buf += chunk
    head, _, rest = buf.partition(b"\r\n\r\n")
    lines = head.split(b"\r\n")
    if b"101" not in lines[0]:
        raise RuntimeError("handshake refused: %s" % lines[0].decode(errors="replace"))

    got = ""
    for ln in lines[1:]:
        name, _, value = ln.partition(b":")
        if name.strip().lower() == b"sec-websocket-accept":
            got = value.strip().decode()
    want = accept_key(key)
    if got != want:
        # Not pedantry: a proxy or plain HTTP server can answer 101 and not be
        # a WebSocket peer.  Verifying the digest is what makes it meaningful.
        raise RuntimeError("Sec-WebSocket-Accept mismatch: got %r, want %r" % (got, want))
    return rest


def encode_text(payload: bytes) -> bytes:
    """A client MUST mask every frame it sends (RFC 6455)."""
    header = bytearray([0x81])
    n = len(payload)
    if n <= 125:
        header.append(0x80 | n)
    elif n <= 0xFFFF:
        header.append(0x80 | 126)
        header += struct.pack(">H", n)
    else:
        header.append(0x80 | 127)
        header += struct.pack(">Q", n)
    mask = os.urandom(4)
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    return bytes(header) + mask + masked


def decode_frames(buf: bytes):
    """Yield (opcode, payload) for every COMPLETE frame; return the remainder."""
    out = []
    while True:
        if len(buf) < 2:
            break
        b0, b1 = buf[0], buf[1]
        opcode = b0 & 0x0F
        masked = bool(b1 & 0x80)
        ln = b1 & 0x7F
        i = 2
        if ln == 126:
            if len(buf) < 4:
                break
            ln = struct.unpack(">H", buf[2:4])[0]
            i = 4
        elif ln == 127:
            if len(buf) < 10:
                break
            ln = struct.unpack(">Q", buf[2:10])[0]
            i = 10
        if masked:
            # A server must not mask.  Say so rather than silently coping.
            raise RuntimeError("server sent a MASKED frame -- protocol violation")
        if len(buf) < i + ln:
            break
        out.append((opcode, buf[i:i + ln]))
        buf = buf[i + ln:]
    return out, buf


def reader(sock, rest, stop):
    buf = rest
    while not stop.is_set():
        try:
            chunk = sock.recv(4096)
        except OSError:
            break
        if not chunk:
            print("\n[server closed the connection]")
            stop.set()
            break
        buf += chunk
        try:
            frames, buf = decode_frames(buf)
        except RuntimeError as e:
            print("\n[%s]" % e)
            stop.set()
            break
        for opcode, payload in frames:
            if opcode == 0x1:
                for msg in payload.decode("latin-1").replace(";", ";\n").splitlines():
                    if msg.strip():
                        print("%s  <  %s" % (time.strftime("%H:%M:%S"), msg.strip()))
            elif opcode == 0x8:
                print("\n[server sent CLOSE]")
                stop.set()
            elif opcode == 0x9:
                sock.sendall(encode_text(payload))     # PONG echoes the payload


def run(host, port):
    sock = socket.create_connection((host, port), timeout=5)
    sock.settimeout(None)
    rest = handshake(sock, host, port)
    print("connected to %s:%d -- type a command (';' added if missing), Ctrl-C to quit" % (host, port))
    print("examples:  vfo:1,0;   vfo:1,0,7040000;   trx:1,true;   split_enable:0,true;")
    print()

    stop = threading.Event()
    t = threading.Thread(target=reader, args=(sock, rest, stop), daemon=True)
    t.start()
    try:
        while not stop.is_set():
            line = sys.stdin.readline()
            if not line:
                break
            line = line.strip()
            if not line:
                continue
            if not line.endswith(";"):
                line += ";"
            print("%s  >  %s" % (time.strftime("%H:%M:%S"), line))
            sock.sendall(encode_text(line.encode()))
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        try:
            sock.close()
        except OSError:
            pass
        print("closed")


def selftest():
    """Client against a minimal server, in-process.  No TR4W, no radio."""
    import http.server  # noqa: F401  (kept for the stdlib import cost only)

    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(1)
    port = srv.getsockname()[1]
    seen = []

    def server():
        conn, _ = srv.accept()
        buf = b""
        while b"\r\n\r\n" not in buf:
            buf += conn.recv(4096)
        key = ""
        for ln in buf.split(b"\r\n"):
            n, _, v = ln.partition(b":")
            if n.strip().lower() == b"sec-websocket-key":
                key = v.strip()
        conn.sendall(
            b"HTTP/1.1 101 Switching Protocols\r\n"
            b"Upgrade: websocket\r\nConnection: Upgrade\r\n"
            b"Sec-WebSocket-Accept: " + accept_key(key).encode() + b"\r\n\r\n")
        # unmasked server frame, as the RFC requires
        body = b"vfo:1,0,7040000;"
        conn.sendall(bytes([0x81, len(body)]) + body)
        # read one masked client frame back
        data = b""
        while len(data) < 2:
            data += conn.recv(4096)
        ln = data[1] & 0x7F
        while len(data) < 2 + 4 + ln:
            data += conn.recv(4096)
        mask = data[2:6]
        seen.append(bytes(b ^ mask[i % 4] for i, b in enumerate(data[6:6 + ln])))
        conn.close()

    threading.Thread(target=server, daemon=True).start()

    sock = socket.create_connection(("127.0.0.1", port), timeout=5)
    rest = handshake(sock, "127.0.0.1", port)
    ok = True

    buf = rest
    while True:
        frames, buf = decode_frames(buf)
        if frames:
            break
        buf += sock.recv(4096)
    got = frames[0][1].decode()
    print("  %s  server->client: %r" % ("PASS" if got == "vfo:1,0,7040000;" else "FAIL", got))
    ok &= got == "vfo:1,0,7040000;"

    sock.sendall(encode_text(b"trx:1,true;"))
    time.sleep(0.4)
    sent = seen[0].decode() if seen else ""
    print("  %s  client->server: %r  (unmasked correctly by the peer)"
          % ("PASS" if sent == "trx:1,true;" else "FAIL", sent))
    ok &= sent == "trx:1,true;"

    print("  %s  accept-key RFC 6455 s1.3 vector"
          % ("PASS" if accept_key(b"dGhlIHNhbXBsZSBub25jZQ==") == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=" else "FAIL"))
    ok &= accept_key(b"dGhlIHNhbXBsZSBub25jZQ==") == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="

    sock.close()
    print("\nall tests passed" if ok else "\nFAILURES -- do not use this against TR4W")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description="Hand-driven TCI client.")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=50001)
    ap.add_argument("--selftest", action="store_true",
                    help="run against an in-process server; no TR4W, no radio")
    args = ap.parse_args()
    if args.selftest:
        sys.exit(selftest())
    run(args.host, args.port)


if __name__ == "__main__":
    main()
