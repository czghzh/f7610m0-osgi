#!/bin/sh
# 一键回退：恢复原始 CuInformLoader（要求：overlayfs 里先 cp 再 rm，不能 mv）
set -x
BAK=/usr/pre_plugin/pre_CuInform_F7610U/CuInformLoader      # 只读 squashfs，永远在
A=/opt/cu/apps/CuInformUpper/CuInformLoader                 # upper 层的包装脚本
R=/opt/cu/apps/CuInformUpper/CuInformLoader.real            # upper 层的真身

[ -f "$BAK" ] || { echo "!! 找不到原始 CuInformLoader"; exit 1; }

cp -f "$BAK" /CuInform/CuInformLoader
rm -f "$A" "$R"
chmod 755 /CuInform/CuInformLoader
md5sum /CuInform/CuInformLoader
sync
echo "-- rollback done，期望 md5 = fde078ffeec505f3b2d38ff4cd2f1a4d --"
echo "-- 必须重启一次，否则 overlay dentry 残留会让 nlink 显示为 0 --"
