#!/usr/bin/env python3
"""TCP 接收端：监听端口，把收到的数据写入文件并打印 md5。
用法: python3 receiver.py <port> <outfile>
"""
import hashlib
import socket
import sys

port = int(sys.argv[1])
out = sys.argv[2]

srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("0.0.0.0", port))
srv.listen(1)
print("listening on %d -> %s" % (port, out), flush=True)

c, addr = srv.accept()
print("connection from %s:%d" % addr, flush=True)

h = hashlib.md5()
total = 0
with open(out, "wb") as f:
    while True:
        d = c.recv(65536)
        if not d:
            break
        f.write(d)
        h.update(d)
        total += len(d)

c.close()
srv.close()
print("received %d bytes  md5=%s" % (total, h.hexdigest()), flush=True)
