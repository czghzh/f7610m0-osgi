#!/bin/bash
# 注释跳板机上 nf_conntrack_udp_timeout / _stream
# 兼容：sudo 免密 / sudo 需密码(密码同 ssh 密码 wen) / 文件 immutable
# 用法: comment_udp.sh <跳板IP>
set -u
J="$1"
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=password -o PubkeyAuthentication=no"

sshpass -p wen ssh $SSHO "wen@$J" 'set -u
TS=$(date +%Y%m%d_%H%M%S)
# 统一 sudo 入口：免密就免密，需要密码就喂 wen
if sudo -n true 2>/dev/null; then
    SDO() { sudo "$@"; }
else
    SDO() { echo wen | sudo -S -p "" "$@"; }
fi
echo "host=$(hostname) ts=$TS"

for f in /etc/sysctl.conf /etc/sysctl.d/99-custom.conf; do
    [ -f "$f" ] || { echo "  $f 不存在，跳过"; continue; }
    if ! grep -qE "^[[:space:]]*net\.netfilter\.nf_conntrack_udp_timeout(_stream)?[[:space:]]*=" "$f"; then
        echo "  $f 无未注释目标行，跳过"; continue
    fi

    IMM=""
    if lsattr "$f" 2>/dev/null | grep -q "^....i"; then
        IMM=1
        SDO chattr -i "$f" 2>/dev/null || { echo "  !! $f 解 immutable 失败"; continue; }
    fi

    if ! SDO cp -a "$f" "$f.bak_udp_$TS" 2>/dev/null; then
        echo "  !! $f 备份失败，不动它"
        [ -n "$IMM" ] && SDO chattr +i "$f" 2>/dev/null
        continue
    fi

    SDO sed -E "s~^([[:space:]]*)(net\.netfilter\.nf_conntrack_udp_timeout(_stream)?[[:space:]]*=)~\1# \2~" "$f" > /tmp/_udp_new.$$ 2>/dev/null \
      && SDO sh -c "cat /tmp/_udp_new.$$ > $f" && rm -f /tmp/_udp_new.$$

    [ -n "$IMM" ] && SDO chattr +i "$f" 2>/dev/null
    echo "  $f 已注释，备份 $f.bak_udp_$TS，immutable=${IMM:-无}"
done

echo "--- 改后 ---"
grep -nE "nf_conntrack_udp_timeout" /etc/sysctl.conf /etc/sysctl.d/99-custom.conf 2>/dev/null
echo "--- 恢复内核默认 30/180 ---"
SDO sh -c "echo 30 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout; echo 180 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream"
echo "udp_timeout=$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout) udp_timeout_stream=$(cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream)"
' 2>&1 | grep -v Warning
