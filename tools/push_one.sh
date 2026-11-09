#!/bin/bash
# 向一台远端光猫推送 root.sh（经跳板机），不重启
# 用法: push_one.sh <跳板IP>
set -u
J=$1
BASE=/home/wen/WorkBuddy/f7610m0
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
export SSHPASS=wen

sshpass -e scp -O $SSHO "$BASE/deploy/root.sh" "wen@$J:/tmp/root.sh" >/dev/null 2>&1 || { echo "[$J] scp root.sh 失败"; exit 1; }
sshpass -e scp -O $SSHO "$BASE/tools/tnt.py"  "wen@$J:/tmp/tnt.py"  >/dev/null 2>&1 || { echo "[$J] scp tnt.py 失败"; exit 1; }
sshpass -e scp -O $SSHO "$BASE/tools/ont_deploy.sh" "wen@$J:/tmp/ont_deploy.sh" >/dev/null 2>&1 || { echo "[$J] scp ont_deploy.sh 失败"; exit 1; }

LANIP=$(sshpass -e ssh $SSHO "wen@$J" "ip -4 -o addr show | grep -o '192\.168\.[0-9]*\.[0-9]*' | head -1" 2>/dev/null | tr -d '\r')
[ -n "$LANIP" ] || { echo "[$J] 取不到 LAN IP"; exit 1; }

echo "[$J] LAN=$LANIP"
sshpass -e ssh $SSHO "wen@$J" "bash /tmp/ont_deploy.sh 192.168.1.1 $LANIP 0 /tmp" 2>&1 | tr -d '\r' | sed "s/^/[$J] /"
