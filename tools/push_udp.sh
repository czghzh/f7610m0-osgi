#!/bin/bash
# 用法: push_udp.sh <跳板IP> <跳板LAN IP> <http端口> <本地隧道端口>
# 把 deploy/root.sh 推到光猫 /usr/plugin/boot.d/root.sh（只覆盖脚本文件，不执行、不重启）
set -u
J="$1"; IP="$2"; HP="$3"; LP="$4"
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
BASE=/home/wen/WorkBuddy/f7610m0

echo "--- [$J] 推送文件到跳板 ---"
sshpass -p wen scp -O $SSHO "$BASE/deploy/root.sh" "wen@$J:/tmp/root.sh" 2>&1 | grep -v Warning
sshpass -p wen ssh $SSHO "wen@$J" "ls -l /tmp/root.sh" 2>&1 | grep -v Warning

echo "--- [$J] 起 http ---"
sshpass -p wen ssh $SSHO "wen@$J" "cd /tmp; nohup setsid python3 -m http.server $HP >/tmp/http_$HP.log 2>&1 </dev/null & sleep 2; curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://127.0.0.1:$HP/root.sh" 2>&1 | grep -v Warning

echo "--- [$J] 光猫拉取覆盖 ---"
printf 'mkdir -p /upgtempfile\nwget -q -O /upgtempfile/root.sh http://%s:%s/root.sh\nwc -c /upgtempfile/root.sh\ncp /upgtempfile/root.sh /usr/plugin/boot.d/root.sh\nchmod 700 /usr/plugin/boot.d/root.sh\nchown osgi:root /usr/plugin/boot.d/root.sh\nls -l /usr/plugin/boot.d/root.sh\ngrep -c nf_conntrack_udp_timeout /usr/plugin/boot.d/root.sh\n' "$IP" "$HP" \
    | timeout 60 python3 "$BASE/tools/tnt.py" 127.0.0.1 "$LP" | tail -6

echo "--- [$J] 收 http ---"
sshpass -p wen ssh $SSHO "wen@$J" "pkill -f 'http.server $HP' || true; echo closed" 2>&1 | grep -v Warning
