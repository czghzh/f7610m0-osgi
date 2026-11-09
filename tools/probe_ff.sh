#!/bin/bash
# 206 跳板 -> 光猫 192.168.1.1，读快转表参数（只读）
# 跳板自身 conntrack 满，连接会随机被丢，所以重试若干次
CMDS='echo HFFP=$(cat /proc/net/fastforward/hff_power)
echo FFEP=$(cat /proc/net/fastforward/ffe_power)
echo MAXL3=$(cat /proc/net/fastforward/route_entry_max_num)
echo MAXLOCAL=$(cat /proc/net/fastforward/local_ff_entry_max_num)
echo MAXBR=$(cat /proc/net/fastforward/bridge_entry_max_num)
echo EXPIRE=$(cat /proc/net/fastforward/ffe_expire_time)
echo LPKT=$(cat /proc/net/fastforward/local_packet_max)
echo UPTIME=$(cat /proc/uptime)
echo CT=$(cat /proc/sys/net/netfilter/nf_conntrack_count)
echo CTMAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max)
echo BUK=$(cat /proc/sys/net/netfilter/nf_conntrack_buckets)
echo EST=$(cat /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established)
echo RPS=$(cat /proc/sys/net/core/rps_sock_flow_entries)
echo --- ffe_paras ---
cat /proc/net/fastforward/ffe_paras'

for i in 1 2 3 4 5 6 7 8; do
  out=$(printf '%s\n' "$CMDS" | ZT_TMO=60 timeout 90 python3 /tmp/tnt.py 192.168.1.1 23 2>&1)
  if printf '%s' "$out" | grep -q 'MAXL3='; then
    echo "$out"
    echo "== 第 $i 次连上 =="
    exit 0
  fi
  echo "第 $i 次被丢，重试" >&2
  sleep 1
done
echo "8 次都没连上"
echo "$out" | tail -5
exit 1
