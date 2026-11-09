#!/bin/bash
# 在「离光猫一跳」的机器上执行：把 /tmp/root.sh 推给光猫，跑一次，校验，可选重启
# 用法: ont_deploy.sh <ONT_IP> <本机LAN_IP> <REBOOT:0|1>
# 前置：/tmp/root.sh 和 /tmp/tnt.py 已就位
set -u
ONT=${1:?ont ip}; LANIP=${2:?lan ip}; DO_REBOOT=${3:-0}
WORK=${4:-/tmp}
HP=8903
TMO=${ZT_TMO:-90}

kill_srv() { pkill -f "[h]ttp.server $HP" 2>/dev/null; sleep 1; }

kill_srv
cd "$WORK" || exit 1
nohup setsid python3 -m http.server $HP >/dev/null 2>&1 </dev/null &
sleep 2
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$HP/root.sh" 2>/dev/null)
[ "$code" = "200" ] || { echo "HTTP_SRV_FAIL=$code"; exit 1; }

CMDS="mkdir -p /upgtempfile
wget -q -O /upgtempfile/root.sh http://$LANIP:$HP/root.sh
echo WRC=\$?
echo SIZE=\$(wc -c < /upgtempfile/root.sh)
cp /upgtempfile/root.sh /usr/plugin/boot.d/root.sh
chmod 700 /usr/plugin/boot.d/root.sh
chown osgi:root /usr/plugin/boot.d/root.sh
echo DM5=\$(md5sum /usr/plugin/boot.d/root.sh | awk '{print \$1}')
/userconfig/rootsh
echo MAX=\$(cat /proc/sys/net/netfilter/nf_conntrack_max)
echo BUK=\$(cat /proc/sys/net/netfilter/nf_conntrack_buckets)
echo PR=\$(cat /proc/sys/net/ipv4/ip_local_port_range)
echo EST=\$(cat /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established)
echo UDP=\$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout)
echo UDS=\$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream)
echo RPS=\$(cat /proc/sys/net/core/rps_sock_flow_entries)
echo E3C=\$(cat /sys/class/net/eth3/queues/rx-0/rps_cpus)"

# 光猫自身 conntrack 满时 telnet 会被随机丢，重试
out=""
for i in 1 2 3 4 5 6; do
  out=$(printf '%s\n' "$CMDS" | ZT_TMO=$TMO timeout $((TMO+40)) python3 /tmp/tnt.py $ONT 23 2>&1)
  printf '%s' "$out" | grep -q 'DM5=' && break
  sleep 2
done
printf '%s\n' "$out" | grep -E 'WRC=|SIZE=|DM5=|MAX=|BUK=|PR=|EST=|UDP=|UDS=|RPS=|E3C=' | sed 's/^/  /'

if [ "$DO_REBOOT" = "1" ]; then
  echo "  -- reboot --"
  printf 'sync\nreboot\n' | ZT_TMO=15 timeout 30 python3 /tmp/tnt.py $ONT 23 >/dev/null 2>&1
fi

kill_srv
