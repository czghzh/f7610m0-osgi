#!/bin/sh
# 以 root 身份执行的开机设置（PCDN 网关调优版）
LOG=/usr/plugin/root.log
{
echo "===== $(date) root.sh start uid=$(awk '/Uid:/{print $2}' /proc/self/status) ====="

# ---- conntrack 上限与哈希桶：30000 / buckets 30208 ----
echo 30000 > /proc/sys/net/netfilter/nf_conntrack_max \
    && echo "nf_conntrack_max = $(cat /proc/sys/net/netfilter/nf_conntrack_max)" \
    || echo "nf_conntrack_max 设置失败"
echo 30000 > /sys/module/nf_conntrack/parameters/hashsize \
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

# ---- PCDN：UDP 超时 30 -> 20（无回应单包），180 -> 40（双向流）----
echo 20 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout \
    && echo "udp_timeout = $(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout)" \
    || echo "udp_timeout 设置失败"
echo 40 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream \
    && echo "udp_timeout_stream = $(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream)" \
    || echo "udp_timeout_stream 设置失败"

echo "===== $(date) root.sh done ====="
} >> $LOG
