#!/bin/bash
# 在所有跳板机上设置 conntrack UDP 超时为 20/40 并生效
# 用法: jump_set_udp.sh <ip> [ip...]
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
export SSHPASS=wen
CONF=/etc/sysctl.d/99-custom.conf

REMOTE='
set -e
CONF=/etc/sysctl.d/99-custom.conf
if sudo -n true 2>/dev/null; then
  SUDO="sudo -n"
else
  SUDO="sudo -S"
  echo wen | sudo -S -v 2>/dev/null
  SUDO="sudo -n"
fi
$SUDO cp -a $CONF $CONF.bak.$(date +%Y%m%d%H%M%S)
$SUDO sed -i "/^[[:space:]]*#*[[:space:]]*net\.netfilter\.nf_conntrack_udp_timeout[[:space:]]*=/d" $CONF
$SUDO sed -i "/^[[:space:]]*#*[[:space:]]*net\.netfilter\.nf_conntrack_udp_timeout_stream[[:space:]]*=/d" $CONF
printf "net.netfilter.nf_conntrack_udp_timeout = 20\nnet.netfilter.nf_conntrack_udp_timeout_stream = 40\n" | $SUDO tee -a $CONF >/dev/null
echo "--- sysctl -p ---"
$SUDO sysctl -p $CONF 2>&1 | grep -i "udp_timeout" || true
echo "--- 生效值 ---"
echo "udp_timeout=$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout)"
echo "udp_timeout_stream=$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream)"
echo "文件末尾:"
$SUDO tail -3 $CONF
'

for ip in "$@"; do
  echo "===== $ip ====="
  timeout 40 sshpass -e ssh $SSHO wen@$ip "bash -s" <<< "$REMOTE" 2>&1 | tr -d '\r' | grep -v '^\[sudo\]'
done
