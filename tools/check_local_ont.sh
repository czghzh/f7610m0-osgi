#!/bin/bash
# 读本地光猫（192.168.1.1）当前状态，确认是否被刚才的命令改动过
cd /home/wen/WorkBuddy/f7610m0/.run || exit 1
printf 'echo MD5=$(md5sum /usr/plugin/boot.d/root.sh | awk "{print \\$1}")\necho SIZE=$(wc -c < /usr/plugin/boot.d/root.sh)\necho MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max)\necho UDP=$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout)\necho UDS=$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream)\necho UP=$(cat /proc/uptime)\n' \
  | ZT_TMO=25 timeout 45 python3 tnt.py 192.168.1.1 23 2>&1 | grep -E 'MD5=|SIZE=|MAX=|UDP=|UDS=|UP=|Error|refused'
