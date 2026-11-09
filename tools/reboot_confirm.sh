#!/bin/bash
# 让光猫确实重启，并等它起来（经跳板机）
# 用法: reboot_confirm.sh <跳板IP>
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
export SSHPASS=wen
J=$1

uptime_now() {
  printf 'echo UP=$(cat /proc/uptime)\n' > /tmp/up.cmds
  sshpass -e ssh $SSHO "wen@$J" "ZT_TMO=20 timeout 40 python3 /tmp/tnt.py 192.168.1.1 23 < /tmp/up.cmds" 2>/dev/null | tr -d '\r' | grep -o '^UP=[0-9.]*' | cut -d= -f2
}

before=$(uptime_now)
echo "[$J] 重启前 uptime=${before:-取不到}"

for try in 1 2 3 4; do
  sshpass -e ssh $SSHO "wen@$J" "printf 'sync\nreboot -f\n' | ZT_TMO=12 timeout 25 python3 /tmp/tnt.py 192.168.1.1 23" >/dev/null 2>&1
  echo "[$J] 第 $try 次 reboot 已下发，等待..."
  sleep 45
  for i in $(seq 1 12); do
    up=$(uptime_now)
    if [ -n "$up" ]; then
      awk -v u="$up" -v b="${before:-99999}" 'BEGIN{exit !(u<b-60)}' && { echo "[$J] 已重启，uptime=$up"; exit 0; }
      echo "[$J] 仍在原进程 uptime=$up，再试"
      break
    fi
    sleep 15
  done
done
echo "[$J] 四次都没重启成功"
exit 1
