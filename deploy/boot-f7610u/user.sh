#!/bin/sh
# ============================================================
# F7610U-C 开机自启 · 用户脚本   (宿主机层 / root / 持久)
# 触发链：pc -> /CuInform/CuInformLoader(包装) -> hook.sh -> 本脚本
# 位置  ：/opt/cu/apps/mystuff/user.sh   (mtd12 ubifs, 重启不丢)
# 日志  ：/opt/cu/apps/mystuff/boot.log (每次开机覆盖写一小段)
# 回退  ：sh /opt/cu/apps/mystuff/rollback.sh  然后重启
#
# 只改四个参数：
#   1. nf_conntrack_max                16000 -> 30000
#   2. nf_conntrack_buckets            3300  -> 30208
#   3. ip_local_port_range             32768 61000 -> 1024 65535
#   4. nf_conntrack_tcp_timeout_established  86400 -> 3600
# 其余 conntrack 超时参数一律保持机器默认，不碰。
# ============================================================

echo "[user.sh] start, uptime=$(sed 's/ .*//' /proc/uptime)"
D_SH=/opt/cu/apps/mystuff

# sysctl 节点在 nf_conntrack 模块加载后才出现，而本脚本触发得很早
# （uptime 约 70 秒）。最多等 30 秒，节点出现即走。
NF=/proc/sys/net/netfilter
i=0
while [ ! -w $NF/nf_conntrack_max ] && [ $i -lt 30 ]; do
    sleep 1
    i=$((i + 1))
done
[ $i -gt 0 ] && echo "[user.sh] 等待 $i 秒后 nf_conntrack 节点就绪"

# ---- 1. conntrack 上限 ----
if [ -w $NF/nf_conntrack_max ]; then
    echo "nf_conntrack_max: $(cat $NF/nf_conntrack_max) -> 30000"
    echo 30000 > $NF/nf_conntrack_max && echo "   now = $(cat $NF/nf_conntrack_max)"
else
    echo "!! nf_conntrack_max 不存在或不可写，跳过"
fi

# ---- 2. 哈希桶 ----
# 桶数只能在条目数为 0 时改，否则 EBUSY
H=/sys/module/nf_conntrack/parameters/hashsize
if [ -w $H ]; then
    echo "hashsize: $(cat $H) -> 30208 (count=$(cat $NF/nf_conntrack_count 2>/dev/null))"
    echo 30208 > $H && echo "   now = $(cat $H)"
else
    echo "!! hashsize 不可写，跳过"
fi

# ---- 3. 临时端口池 ----
P=/proc/sys/net/ipv4/ip_local_port_range
if [ -w $P ]; then
    echo "ip_local_port_range: $(cat $P | tr '\n' ' ')-> 1024 65535"
    echo "1024 65535" > $P && echo "   now = $(cat $P | tr '\n' ' ')"
fi

# ---- 4. TCP established 超时 ----
T=$NF/nf_conntrack_tcp_timeout_established
if [ -w $T ]; then
    echo "tcp_timeout_established: $(cat $T) -> 3600"
    echo 3600 > $T && echo "   now = $(cat $T)"
fi

# ---- 生效结果汇总 ----
echo "--- 最终值 ---"
for f in nf_conntrack_max nf_conntrack_count nf_conntrack_buckets \
         nf_conntrack_tcp_timeout_established; do
    [ -r $NF/$f ] && echo "  $f = $(cat $NF/$f)"
done
[ -r $P ] && echo "  ip_local_port_range = $(cat $P | tr '\n' ' ')"

echo "[user.sh] done"

# ---- 延时复查 ----
# cspd 在启动后几十秒内会重写部分 conntrack 参数。这里只管我们自己设的
# 那几项：掉的就补回去。只跑一次，做完就退出，不留常驻进程。
(
  sleep 90
  echo "----- 延时复查 uptime=$(sed 's/ .*//' /proc/uptime) -----" >> $D_SH/boot.log
  [ "$(cat $NF/nf_conntrack_max 2>/dev/null)" = "30000" ] || { echo 30000 > $NF/nf_conntrack_max; echo "补设 nf_conntrack_max=30000" >> $D_SH/boot.log; }
  [ "$(cat $T 2>/dev/null)" = "3600" ] || { echo 3600 > $T; echo "补设 tcp_timeout_established=3600" >> $D_SH/boot.log; }
  echo "  复查后：max=$(cat $NF/nf_conntrack_max) buckets=$(cat $NF/nf_conntrack_buckets) tcp_est=$(cat $T)" >> $D_SH/boot.log
  echo "----- 复查结束 -----" >> $D_SH/boot.log
) >/dev/null 2>&1 &

exit 0
