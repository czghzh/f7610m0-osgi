#!/bin/sh
# 开机启动脚本（osgi 用户身份运行）
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/java/bin
export LD_LIBRARY_PATH=/lib:/usr/lib
LOG=/usr/plugin/startup.log
echo "=== $(date) startup as uid=$(awk '/Uid:/{print $2}' /proc/self/status)" >> $LOG

# ---- 需要 root 的部分：经 /userconfig 里的 setuid 助手 ----
# /usr/plugin 开机会被整分区 chown 成 osgi（chown 会清 setuid 位），
# 所以 rootsh 必须放在不会被归一化的 /userconfig（root 属主 jffs2）
[ -x /userconfig/rootsh ] && /userconfig/rootsh >> $LOG 2>&1

# ---- 以 osgi 身份运行的程序写在这里 ----
# 例：/usr/plugin/bin/myapp >> /usr/plugin/myapp.log 2>&1 &

echo "=== $(date) startup done ===" >> $LOG
