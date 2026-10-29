#!/bin/sh
# 以 root 身份执行的开机设置
LOG=/usr/plugin/root.log
{
echo "===== $(date) root.sh start uid=$(awk '/Uid:/{print $2}' /proc/self/status) ====="

# conntrack 上限与哈希桶：16000/3584 -> 30000
echo 30000 > /proc/sys/net/netfilter/nf_conntrack_max \
    && echo "nf_conntrack_max = $(cat /proc/sys/net/netfilter/nf_conntrack_max)" \
    || echo "nf_conntrack_max 设置失败"
echo 30000 > /sys/module/nf_conntrack/parameters/hashsize \
    && echo "nf_conntrack_buckets = $(cat /proc/sys/net/netfilter/nf_conntrack_buckets)" \
    || echo "hashsize 设置失败"

echo "===== $(date) root.sh done ====="
} >> $LOG
