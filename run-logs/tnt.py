#!/usr/bin/env python3
"""最小 telnet 客户端：通过本地端口（ssh -L 隧道）登录中兴光猫并批量执行命令。

用法：
  python3 tnt.py <host> <port> < cmds.txt

环境变量：
  ZT_USER  默认 root
  ZT_PASS  默认 Zte521
  ZT_TMO   总超时秒数，默认 40

设计：命令一次性发完，末尾 echo 哨兵，只等一次。
"""
import os
import re
import socket
import sys
import time

USER = os.environ.get("ZT_USER", "root")
PASS = os.environ.get("ZT_PASS", "Zte521")
TOTAL = float(os.environ.get("ZT_TMO", "40"))
SENT = "__TNT_DONE_9182__"


class Conn:
    def __init__(self, host, port):
        self.s = socket.create_connection((host, port), timeout=10)
        self.s.settimeout(1.0)
        self.buf = b""
        self.pending = b""   # 跨包未完成的 IAC 序列

    def _strip_iac(self, data: bytes) -> bytes:
        # 先把上一包遗留的未完成 IAC 序列接上
        if self.pending:
            data = self.pending + data
            self.pending = b""
        out = bytearray()
        i = 0
        n = len(data)
        while i < n:
            b = data[i]
            if b == 255:  # IAC
                if i + 1 >= n:
                    self.pending = data[i:]      # 跨包截断，留到下一包
                    break
                cmd = data[i + 1]
                if cmd in (251, 252, 253, 254):  # WILL/WONT/DO/DONT + option
                    if i + 2 >= n:
                        self.pending = data[i:]
                        break
                    i += 3
                    continue
                if cmd == 250:  # SB ... IAC SE
                    j = data.find(b"\xff\xf0", i)
                    if j == -1:
                        self.pending = data[i:]  # 子协商未结束
                        break
                    i = j + 2
                    continue
                i += 2
                continue
            out.append(b)
            i += 1
        return bytes(out)

    def feed(self, timeout):
        end = time.time() + timeout
        while time.time() < end:
            try:
                d = self.s.recv(8192)
                if not d:
                    break
                self.buf += self._strip_iac(d)
            except socket.timeout:
                continue
        return self.buf.decode("utf-8", "replace")

    def expect(self, pat, timeout):
        end = time.time() + timeout
        rx = re.compile(pat)
        while time.time() < end:
            txt = self.buf.decode("utf-8", "replace")
            m = rx.search(txt)
            if m:
                self.buf = txt[m.end():].encode()
                return True
            try:
                d = self.s.recv(8192)
                if not d:
                    return False
                self.buf += self._strip_iac(d)
            except socket.timeout:
                continue
        return False

    def send(self, text):
        self.s.sendall(text.encode())

    def read_until(self, marker, timeout):
        end = time.time() + timeout
        while time.time() < end:
            if marker.encode() in self.buf:
                return self.buf.decode("utf-8", "replace")
            try:
                d = self.s.recv(8192)
                if not d:
                    break
                self.buf += self._strip_iac(d)
            except socket.timeout:
                continue
        return self.buf.decode("utf-8", "replace")


def main():
    if len(sys.argv) < 3:
        print("usage: tnt.py <host> <port>", file=sys.stderr)
        return 2
    host, port = sys.argv[1], int(sys.argv[2])
    cmds = [l.rstrip("\n") for l in sys.stdin if l.strip()]
    if not cmds:
        return 0

    c = Conn(host, port)
    try:
        # 中兴 telnetd 先发 IAC 协商，再晚一点才给 Login 提示，给足 25 秒
        if not c.expect(r"[Ll]ogin:\s*", 25):
            print("### 没等到 login 提示:", c.buf.decode("utf-8", "replace")[-300:])
            return 1
        c.send(USER + "\n")
        if c.expect(r"[Pp]assword:\s*", 10):
            c.send(PASS + "\n")
        c.expect(r"[#$]\s", 15)

        head = ["trap ':' INT", "export PATH=/bin:/sbin:/usr/bin:/usr/sbin", "cd /"]
        # 逐条发送并留间隔：busybox telnetd 连续灌命令会丢掉新命令的首字符
        for ln in head + cmds:
            c.send(ln + "\n")
            time.sleep(0.06)
        c.send("echo %s\n" % SENT)
        out = c.read_until(SENT, TOTAL)
        # 去掉提示符前缀与哨兵
        lines = []
        for line in out.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
            s = re.sub(r"^\s*[^\s#]{0,40}\s#\s?", "", line)
            if SENT in s:
                continue
            lines.append(s)
        print("\n".join(lines).strip())
        return 0
    finally:
        c.s.close()


if __name__ == "__main__":
    sys.exit(main())
