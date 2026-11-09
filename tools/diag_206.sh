#!/bin/bash
# 诊断：光猫 192.168.1.1 管理面为何不可达
# 1) 换一个源 IP 再试，区分「本机被拉黑」还是「管理面整体关闭」

probe() {
  ip=$1; p=$2; src=$3
  python3 - "$ip" "$p" "$src" <<'PY'
import socket, sys
ip, p, src = sys.argv[1], int(sys.argv[2]), sys.argv[3]
s = socket.socket(); s.settimeout(3)
try:
    if src: s.bind((src, 0))
    s.connect((ip, p)); print(f"{ip}:{p} src={src or '-'} OPEN")
except Exception as e:
    print(f"{ip}:{p} src={src or '-'} {type(e).__name__}")
finally:
    s.close()
PY
}

echo "== 本机地址 =="
ip -4 addr show eth0 | grep 'inet '

echo "== 原源 IP 探测 =="
probe 192.168.1.1 23 ""
probe 192.168.1.1 80 ""

echo "== 找一个空闲 IP 作临时源地址 =="
FREE=""
for i in 240 241 242 243; do
  if ! ping -c 1 -W 1 192.168.1.$i >/dev/null 2>&1; then FREE=192.168.1.$i; break; fi
done
echo "free=$FREE"

if [ -n "$FREE" ]; then
  ip addr add $FREE/24 dev eth0 2>/dev/null && echo "已加别名 $FREE" || echo "加别名失败"
  probe 192.168.1.1 23 "$FREE"
  probe 192.168.1.1 80 "$FREE"
  ip addr del $FREE/24 dev eth0 2>/dev/null && echo "已删除别名 $FREE"
fi

echo "== 网关 ARP 与 MAC 厂商 =="
ip neigh show 192.168.1.1
echo "== 本机默认路由 =="
ip route | grep default
