#!/bin/bash
# 发现哪些跳板机可达，以及能否提权、现有 sysctl 配置
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
export SSHPASS=wen

for ip in 100.64.64.102 100.64.64.104 100.64.64.105 100.64.64.107 100.64.64.201 100.64.64.202 100.64.64.203 100.64.64.205 100.64.64.206 100.64.64.210; do
  out=$(timeout 20 sshpass -e ssh $SSHO wen@$ip '
    echo "HOST=$(hostname)"
    echo "OS=$(grep PRETTY /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d \")"
    echo "SUDO_N=$(sudo -n true 2>&1 && echo yes || echo no)"
    echo "FILE=$(ls /etc/sysctl.d/99-custom.conf 2>/dev/null || echo none)"
    echo "CUR=$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout 2>/dev/null)/$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream 2>/dev/null)"
    echo "MOD=$(lsmod | grep -c nf_conntrack)"
    echo "CT=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null)/$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null)"
  ' 2>&1 | tr -d '\r')
  if [ -z "$out" ] || printf '%s' "$out" | grep -q "Permission denied\|Connection refused\|timed out"; then
    printf "%-16s UNREACHABLE  %s\n" "$ip" "$(printf '%s' "$out" | tail -1)"
  else
    printf "%-16s %s\n" "$ip" "$(printf '%s' "$out" | tr '\n' ' ')"
  fi
done
