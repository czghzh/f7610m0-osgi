#!/usr/bin/env python3
"""TCP 发送端：监听端口，把指定文件发给连上来的客户端。
用法: python3 sender.py <port> <file>
"""
import socket
import sys
import time

port = int(sys.argv[1])
path = sys.argv[2]

srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 4 * 1024 * 1024)
srv.bind(("0.0.0.0", port))
srv.listen(1)
print("listening %d -> %s" % (port, path), flush=True)

c, addr = srv.accept()
c.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 4 * 1024 * 1024)
print("client %s:%d" % addr, flush=True)

total = 0
t0 = time.time()
with open(path, "rb") as f:
    while True:
        d = f.read(262144)
        if not d:
            break
        c.sendall(d)
        total += len(d)
c.close()
srv.close()
dt = time.time() - t0
print("sent %d bytes in %.1fs (%.1f KB/s)" % (total, dt, total / 1024 / max(dt, 0.001)), flush=True)
