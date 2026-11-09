#!/bin/bash
# 通过跳板机让光猫重启
# 用法: reboot_ont.sh <跳板IP>
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
export SSHPASS=wen
J=$1
sshpass -e ssh $SSHO "wen@$J" "printf 'sync\nreboot\n' | ZT_TMO=12 timeout 25 python3 /tmp/tnt.py 192.168.1.1 23" >/dev/null 2>&1
echo "[$J] reboot 已下发"
