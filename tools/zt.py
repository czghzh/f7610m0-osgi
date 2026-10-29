#!/usr/bin/env python3
"""ZTE ONT telnet 批量执行工具。

用法：
  printf 'cmd1\ncmd2\n' | python zt.py

环境变量：
  ZT_TMO   整批命令的总超时秒数（默认 30）
  ZT_HOST  设备地址（默认 192.168.1.1）

设计：所有命令一次性灌进去，末尾 echo 一个哨兵，只做一次等待。
比"每条命令各等一次提示符"快一个数量级，也不会因为某条命令慢而累加超时。
"""
import os
import re
import sys

import pexpect

HOST = os.environ.get("ZT_HOST", "192.168.1.1")
USER = os.environ.get("ZT_USER", "root")
PASS = os.environ.get("ZT_PASS", "Zte521")
TOTAL = int(os.environ.get("ZT_TMO", "30"))
SENTINEL = "__ZT_DONE_7319__"

BASE = ["trap ':' INT", "export PATH=/bin:/sbin:/usr/bin:/usr/sbin", "cd /"]


def clean(text, cmds):
    """去掉回显的命令行、提示符前缀与哨兵。"""
    out = []
    seen = {c.strip() for c in cmds if c.strip()} | {c.strip() for c in BASE}
    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        # 去掉 "/ # "、"~ # " 这类提示符前缀
        line = re.sub(r"^\s*[^\s#]{0,40}\s#\s?", "", line)
        s = line.strip()
        if s in seen or s in ("echo",) or SENTINEL in s:
            continue
        out.append(line)
    while out and not out[0].strip():
        out.pop(0)
    while out and not out[-1].strip():
        out.pop()
    return "\n".join(out)


def main():
    cmds = [l.rstrip("\n") for l in sys.stdin if l.strip()]
    if not cmds:
        return 0

    p = pexpect.spawn(f"telnet {HOST}", timeout=6, encoding="utf-8",
                      codec_errors="replace", dimensions=(200, 400))
    try:
        i = p.expect([r"[Ll]ogin:\s*", r"[Uu]sername:\s*", pexpect.TIMEOUT, pexpect.EOF], timeout=8)
        if i >= 2:
            print("### 连不上或没有 login 提示:", (p.before or "")[-200:])
            return 1
        p.sendline(USER)
        p.expect([r"[Pp]assword:\s*", pexpect.TIMEOUT], timeout=6)
        p.sendline(PASS)
        # 等 shell 起来即可，不依赖具体提示符
        p.expect([r"[#$>]\s", pexpect.TIMEOUT], timeout=8)
        try:
            p.read_nonblocking(size=65536, timeout=0.2)
        except Exception:
            pass

        p.send("\n".join(BASE + cmds) + f"\necho {SENTINEL}\n")
        got = p.expect([SENTINEL, pexpect.TIMEOUT, pexpect.EOF], timeout=TOTAL)
        print(clean(p.before or "", cmds))
        if got != 0:
            print(f"\n### 超时（{TOTAL}s）或连接中断，以上为已收到的部分输出")
            return 2
        return 0
    finally:
        p.close(force=True)


if __name__ == "__main__":
    sys.exit(main())
