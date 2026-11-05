#!/bin/sh
# 以 root 身份执行的开机设置（PCDN 网关调优版）
LOG=/usr/plugin/root.log
{
echo "===== $(date) root.sh start uid=$(awk '/Uid:/{print $2}' /proc/self/status) ====="

# ---- conntrack 上限与哈希桶：40960 / 40960 ----
echo 40960 > /proc/sys/net/netfilter/nf_conntrack_max \
    && echo "nf_conntrack_max = $(cat /proc/sys/net/netfilter/nf_conntrack_max)" \
    || echo "nf_conntrack_max 设置失败"
# hashsize 会被内核上调到 512 的整数倍（实测，内核 4.1.25 / ZX279131）：
#   写 512 的整数倍 -> 原样保留      32768->32768  39936->39936  40448->40448
#                                    40960->40960  41984->41984  45056->45056
#   写非 512 整数倍 -> 上取整        39937->40448  40192->40448  40961->41472
# 所以 40192（78.5x512）永远读回 40448；想让写入值=回读值，就必须写 512 的倍数。
# 40960 = 40x1024 = 80x512，写多少读多少，buckets 与 max 1:1。
# 注意：hashsize 节点只写不读（cat 报权限不够），只能用 buckets 回读校验。
echo 40960 > /sys/module/nf_conntrack/parameters/hashsize \
    && echo "nf_conntrack_buckets = $(cat /proc/sys/net/netfilter/nf_conntrack_buckets)" \
    || echo "hashsize 设置失败"

# ---- PCDN：临时端口池 32768-61000 -> 1024-65535（28233 -> 64512）----
echo "1024 65535" > /proc/sys/net/ipv4/ip_local_port_range \
    && echo "ip_local_port_range = $(cat /proc/sys/net/ipv4/ip_local_port_range)" \
    || echo "ip_local_port_range 设置失败"

# ---- PCDN：TCP established 超时 86400(24h) -> 3600(1h)，加快条目回收 ----
echo 3600 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established \
    && echo "tcp_timeout_established = $(cat /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established)" \
    || echo "tcp_timeout_established 设置失败"

# ---- RPS：收包软处理推给 CPU1（flow 表 65536，eth0~eth3）----
# rps_* 走的是 roundup_pow_of_two（向上取整到 2 的幂），写 40192 会变成 65536；
# 这里直接写 65536，写入值与回读值一致。rps_flow_cnt 不能大于全局 entries。
echo 65536 > /proc/sys/net/core/rps_sock_flow_entries
echo 65536 > /sys/class/net/eth0/queues/rx-0/rps_flow_cnt
echo 2     > /sys/class/net/eth0/queues/rx-0/rps_cpus
echo 65536 > /sys/class/net/eth1/queues/rx-0/rps_flow_cnt
echo 2     > /sys/class/net/eth1/queues/rx-0/rps_cpus
echo 65536 > /sys/class/net/eth2/queues/rx-0/rps_flow_cnt
echo 2     > /sys/class/net/eth2/queues/rx-0/rps_cpus
echo 65536 > /sys/class/net/eth3/queues/rx-0/rps_flow_cnt
echo 2     > /sys/class/net/eth3/queues/rx-0/rps_cpus
echo "rps_sock_flow_entries = $(cat /proc/sys/net/core/rps_sock_flow_entries) / eth3 rps_cpus = $(cat /sys/class/net/eth3/queues/rx-0/rps_cpus)"

echo "===== $(date) root.sh done ====="
} >> $LOG
