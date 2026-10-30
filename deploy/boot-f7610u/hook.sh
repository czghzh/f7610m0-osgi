#!/bin/sh
# 开机入口：由 /CuInform/CuInformLoader 包装脚本调用（宿主机层，root）
# 日志只保留最近一次开机（覆盖写，不追加，避免长期占用 flash）
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
D=/opt/cu/apps/mystuff
LOG=$D/boot.log

{
echo "===== $(date) loader hook, uptime=$(sed 's/ .*//' /proc/uptime) ====="
if [ -x $D/user.sh ]; then
    $D/user.sh
    echo "-- user.sh rc=$? --"
else
    echo "!! $D/user.sh 不存在或不可执行"
fi
} > $LOG 2>&1

# 清掉自己：hook.sh 是被包装脚本放到后台跑的孤儿进程（PPID=1），
# 没有人 wait 它，不改的话会留一个 Z 僵尸。init 不会自动回收。
kill -9 $$
