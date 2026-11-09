#!/bin/bash
# 重启后验证一台光猫（经跳板机），带等待与重试
# 用法: verify_ont.sh <跳板IP>
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
export SSHPASS=wen
J=$1

# 1) 等跳板机自己恢复（光猫重启期间它断网，Tailscale 会掉）
for i in $(seq 1 30); do
  sshpass -e ssh $SSHO "wen@$J" "true" >/dev/null 2>&1 && break
  sleep 10
done

CMDS="echo UP=\$(cat /proc/uptime)
echo MAX=\$(cat /proc/sys/net/netfilter/nf_conntrack_max)
echo BUK=\$(cat /proc/sys/net/netfilter/nf_conntrack_buckets)
echo PR=\$(cat /proc/sys/net/ipv4/ip_local_port_range)
echo EST=\$(cat /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established)
echo UDP=\$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout)
echo UDS=\$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream)
echo RPS=\$(cat /proc/sys/net/core/rps_sock_flow_entries)
echo E3C=\$(cat /sys/class/net/eth3/queues/rx-0/rps_cpus)
echo --- LOG ---
awk '{a[NR]=\$0} END{s=NR-7; for(i=s;i<=NR;i++) print a[i]}' /usr/plugin/root.log"

for i in $(seq 1 20); do
  sshpass -e ssh $SSHO "wen@$J" "true" >/dev/null 2>&1 && break
  sleep 10
done

# 干净做法：把命令写到跳板机上的文件，再 pipe 给 tnt.py
sshpass -e ssh $SSHO "wen@$J" "cat > /tmp/veri.cmds" <<< "$CMDS"

for i in $(seq 1 12); do
  out=$(sshpass -e ssh $SSHO "wen@$J" "ZT_TMO=60 timeout 90 python3 /tmp/tnt.py 192.168.1.1 23 < /tmp/veri.cmds" 2>&1 | tr -d '\r')
  printf '%s' "$out" | grep -q 'MAX=' && break
  sleep 10
done
echo "===== $J ====="
printf '%s\n' "$out" | grep -vE '^echo |^\s*$'
