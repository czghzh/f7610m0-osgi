#!/bin/sh
# 把 boot/ 下的脚本推到 F7610U-C 并就地安装
# 用法：bash install.sh            安装
#       bash install.sh --restore  只恢复原样（不重启）
#
# 上传方式：主机起临时 HTTP 服务，设备 busybox wget 走 /upgtempfile 落盘。
# 设备上没有 base64/xxd/uuencode，只有一个静态 Go 二进制 uploader 的旧路子，
# wget 是最省事的。
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ZT="${ZT_BIN:-/home/wen/.workbuddy/binaries/python/envs/default/bin/python}"
ZTPY="${ZT_PY:-/home/wen/WorkBuddy/f7610m0/zt.py}"
D=/opt/cu/apps/mystuff
UP=/opt/cu/apps/CuInformUpper
BAK=/usr/pre_plugin/pre_CuInform_F7610U/CuInformLoader
PORT=8901

run() { printf '%s\n' "$@" | ZT_TMO=60 "$ZT" "$ZTPY"; }

if [ "$1" = "--restore" ]; then
  echo "== 恢复原始 CuInformLoader =="
  run "cp -f $BAK /CuInform/CuInformLoader" \
      "rm -f $UP/CuInformLoader $UP/CuInformLoader.real" \
      "chmod 755 /CuInform/CuInformLoader" \
      "md5sum /CuInform/CuInformLoader" \
      "sync"
  echo "== 完成，需要重启一次才彻底干净 =="
  exit 0
fi

echo "== 1/6 起主机 HTTP 服务 =="
cd "$HERE"
setsid python3 -m http.server $PORT --bind 0.0.0.0 </dev/null >/tmp/httppush.log 2>&1 &
SRV=$!
sleep 1
echo "   pid=$SRV  http://192.168.1.100:$PORT/"
trap 'kill $SRV 2>/dev/null' EXIT

echo "== 2/6 建目录、留底 =="
run "mkdir -p $D" \
    "[ -f $D/CuInformLoader.orig ] || cp -f $BAK $D/CuInformLoader.orig" \
    "ls -la $D/CuInformLoader.orig"

echo "== 3/6 设备 wget 拉取脚本 =="
run "cd /upgtempfile" \
    "rm -f hook.sh user.sh CuInformLoader rollback.sh" \
    "wget -q -O hook.sh         http://192.168.1.100:$PORT/hook.sh" \
    "wget -q -O user.sh         http://192.168.1.100:$PORT/user.sh" \
    "wget -q -O CuInformLoader  http://192.168.1.100:$PORT/CuInformLoader" \
    "wget -q -O rollback.sh     http://192.168.1.100:$PORT/rollback.sh" \
    "ls -la /upgtempfile" \
    "md5sum /upgtempfile/*.sh /upgtempfile/CuInformLoader"
echo "   主机侧参考值："
md5sum hook.sh user.sh CuInformLoader rollback.sh | sed 's/^/     /'

echo "== 4/6 拷入持久目录 + 设权限 + 语法检查 =="
run "cp -f /upgtempfile/hook.sh /upgtempfile/user.sh /upgtempfile/CuInformLoader /upgtempfile/rollback.sh $D/" \
    "chmod 755 $D/hook.sh $D/user.sh $D/CuInformLoader $D/rollback.sh" \
    "sh -n $D/hook.sh && echo hook.sh syntax OK" \
    "sh -n $D/user.sh && echo user.sh syntax OK" \
    "md5sum $D/hook.sh $D/user.sh $D/CuInformLoader"

echo "== 5/6 安装包装脚本到 overlay upper =="
echo "   overlayfs 里必须 cp 复制再 rm 原文件，mv 会丢文件"
run "cp -f $BAK $UP/CuInformLoader.real" \
    "cp -f $D/CuInformLoader $UP/CuInformLoader" \
    "rm -f /CuInform/CuInformLoader" \
    "chmod 755 $UP/CuInformLoader $UP/CuInformLoader.real" \
    "ls -la /CuInform/CuInformLoader /CuInform/CuInformLoader.real" \
    "md5sum /CuInform/CuInformLoader /CuInform/CuInformLoader.real"

echo "== 6/6 空跑一次（先执行一次 user.sh 让参数立刻生效，再清 boot.log） =="
run "sh $D/user.sh > /dev/null 2>&1" \
    "sh -c 'echo \"===== 首次安装实测 $(date) =====\" > $D/boot.log'" 

echo
echo "== 安装完成。重启验证：reboot 后 cat $D/boot.log =="
echo "== 回退：bash install.sh --restore 然后重启 =="
