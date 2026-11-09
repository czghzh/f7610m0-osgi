#!/bin/bash
# 批量推送 root.sh 到光猫
# 用法: push_batch.sh <跳板IP> <跳板LAN_IP> <光猫IP>
set -u
J=$1; LIP=$2; GW=$3
HP=8901
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
BASE=/home/wen/WorkBuddy/f7610m0
export SSHPASS=wen

sshpass -e scp -O $SSHO "$BASE/deploy/root.sh" "wen@$J:/tmp/root.sh" >/dev/null 2>&1 \
  || { echo "[$J] scp root.sh 失败"; exit 1; }

# 注意：pkill 必须单独一次 ssh 调用。
# 若和 nohup python3 -m http.server 写在同一命令行里，pkill -f 会匹配到
# 这条 ssh 远端 shell 自己的 cmdline（里面含 "http.server 8901"）而自杀，
# 导致后面的 nohup 根本执行不到（表现为"http 起不来"）。
sshpass -e ssh $SSHO "wen@$J" "pkill -f '[h]ttp.server $HP' 2>/dev/null; sleep 1; true" >/dev/null 2>&1 || true

sshpass -e ssh $SSHO "wen@$J" \
  "cd /tmp; nohup setsid python3 -m http.server $HP >/dev/null 2>&1 </dev/null & sleep 2; curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$HP/root.sh" 2>/dev/null \
  | grep -q 200 || { echo "[$J] http 起不来"; exit 1; }

sshpass -e ssh $SSHO "wen@$J" \
"printf 'mkdir -p /upgtempfile\nwget -q -O /upgtempfile/root.sh http://$LIP:$HP/root.sh\necho WRC=\$?\nwc -c /upgtempfile/root.sh\ncp /upgtempfile/root.sh /usr/plugin/boot.d/root.sh\nchmod 700 /usr/plugin/boot.d/root.sh\nchown osgi:root /usr/plugin/boot.d/root.sh\necho SIZE=\$(wc -c < /usr/plugin/boot.d/root.sh)\n/userconfig/rootsh\necho MAX=\$(cat /proc/sys/net/netfilter/nf_conntrack_max)\necho BUK=\$(cat /proc/sys/net/netfilter/nf_conntrack_buckets)\necho RPS=\$(cat /proc/sys/net/core/rps_sock_flow_entries)\necho E3C=\$(cat /sys/class/net/eth3/queues/rx-0/rps_cpus)\n' | ZT_TMO=70 timeout 100 python3 /tmp/tnt.py $GW 23" 2>&1 \
  | tr -d '\r' | grep -E "WRC=|SIZE=|MAX=|BUK=|RPS=|E3C=|^[0-9]+ /upgtempfile" | sed "s/^/[$J] /"

sshpass -e ssh $SSHO "wen@$J" "pkill -f '[h]ttp.server $HP' 2>/dev/null; echo ok" >/dev/null 2>&1
