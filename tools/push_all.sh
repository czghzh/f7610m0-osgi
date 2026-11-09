#!/bin/bash
# 用法: push_all.sh <跳板IP> <跳板LAN IP> <http端口>
# 在跳板机上直接运行 telnet 客户端，避开 ssh -L 转发失效的问题。
set -u
J="$1"; IP="$2"; HP="$3"
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
BASE=/home/wen/WorkBuddy/f7610m0

echo "--- [$J] 上传文件与客户端 ---"
sshpass -p wen scp -O $SSHO "$BASE/deploy/root.sh" "wen@$J:/tmp/root.sh" 2>&1 | grep -v Warning
sshpass -p wen scp -O $SSHO "$BASE/tools/tnt.py" "wen@$J:/tmp/tnt.py" 2>&1 | grep -v Warning
sshpass -p wen ssh $SSHO "wen@$J" "wc -c /tmp/root.sh" 2>&1 | grep -v Warning

echo "--- [$J] 起 http ---"
sshpass -p wen ssh $SSHO "wen@$J" "cd /tmp; nohup setsid python3 -m http.server $HP >/tmp/h_$HP.log 2>&1 </dev/null & sleep 2; curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://127.0.0.1:$HP/root.sh" 2>&1 | grep -v Warning

echo "--- [$J] 远程 telnet 覆盖 ---"
sshpass -p wen ssh $SSHO "wen@$J" "printf 'mkdir -p /upgtempfile\nwget -q -O /upgtempfile/root.sh http://$IP:$HP/root.sh\nwc -c /upgtempfile/root.sh\ncp /upgtempfile/root.sh /usr/plugin/boot.d/root.sh\nchmod 700 /usr/plugin/boot.d/root.sh\nchown osgi:root /usr/plugin/boot.d/root.sh\nls -l /usr/plugin/boot.d/root.sh\ngrep -c udp_timeout /usr/plugin/boot.d/root.sh\n' | timeout 60 python3 /tmp/tnt.py 192.168.1.1 23" 2>&1 | grep -v Warning | tail -6

echo "--- [$J] 收 http ---"
sshpass -p wen ssh $SSHO "wen@$J" "pkill -f 'http.server $HP' 2>/dev/null; echo closed" 2>&1 | grep -v Warning
