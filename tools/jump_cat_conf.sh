#!/bin/bash
# 读取各跳板机上 /etc/sysctl.d/99-custom.conf 现有内容（只读）
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
export SSHPASS=wen

for ip in "$@"; do
  echo "===== $ip ====="
  timeout 25 sshpass -e ssh $SSHO wen@$ip \
    'if sudo -n true 2>/dev/null; then S="sudo -n"; else S="sudo -S"; fi;
     if [ "$S" = "sudo -S" ]; then echo wen | sudo -S cat /etc/sysctl.d/99-custom.conf 2>/dev/null
     else sudo -n cat /etc/sysctl.d/99-custom.conf 2>/dev/null; fi' 2>&1 | tr -d '\r' | grep -v '^\[sudo\]'
done
