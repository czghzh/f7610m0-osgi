# f7610m0-osgi — 中兴 F7610M0 光猫开机自启方案

不碰 rootfs（RSA 签名只读 jffs2）、不碰 U-Boot，实现开机自动执行自定义脚本，
并可在钩子内提权到 root（已冷启动验证）。

完整原理、步骤、踩坑记录见 **[docs/F7610M0_开机自启方案.md](docs/F7610M0_开机自启方案.md)**。

## 原理一句话

`/usr/java` 是 `/usr/tmp/osgi.img`（squashfs）的 loop 挂载，`/usr/tmp` 是可写的
UBI 卷；把镜像里的 `bin/java` 换成 shell 脚本后，`osgid`（每分钟检测 java 进程）
就会反复拉起它 —— 这就是开机钩子。需要 root 的操作经 `/userconfig/rootsh`
（自编译 setuid 执行器）完成。

## 目录结构

| 路径 | 说明 |
|---|---|
| `hook/java` | 替换进 squashfs 的 java 钩子脚本（873B，会调 `/usr/plugin/startup.sh`） |
| `rootsh/rootsh.c` | setuid root 执行器源码（静态 aarch64） |
| `rootsh/rootsh` | 已编译二进制（598KB，直接可用） |
| `deploy/startup.sh` | osgi 身份开机脚本模板（设备端 `/usr/plugin/startup.sh`） |
| `deploy/boot.d/root.sh` | root 身份开机脚本模板（设备端 `/usr/plugin/boot.d/root.sh`，含 conntrack 30000） |
| `images/osgi_new.img` | **改造后镜像**（java 已替换，可直接部署） |
| `images/osgi_orig.img` | **原厂镜像备份**（恢复用） |
| `tools/zt.py` | telnet 批量驱动（`printf 'cmd1\ncmd2\n' \| python zt.py`） |
| `.workbuddy/memory/` | 项目工作记忆快照（MEMORY.md 索引 + 当日记录） |

## 快速部署（新设备）

设备 telnet：`192.168.1.1`，root / Zte521。主机 IP 需为 `192.168.1.100`。

```sh
# 1. 下发镜像与脚本（主机开 http/tftp，设备 wget/tftp 拉取）
#    deploy/startup.sh  ->  /usr/plugin/startup.sh   (755, osgi:root)
#    deploy/boot.d/root.sh -> /usr/plugin/boot.d/root.sh (700, 0:0)
#    rootsh             ->  /userconfig/rootsh       (4755, 0:0)
#    images/osgi_new.img -> 暂存 /usr/plugin/osgi_new.img

# 2. 替换镜像（必须按序，详见 docs）
#    2.1 连杀 java/osgid 并 umount /usr/java（cspd 会抢，循环重试）
#    2.2 mount -o remount,rw ubi0_0 /usr/tmp
#    2.3 rm -f /usr/tmp/osgi.img && sync
#    2.4 reboot          ← 必须重启回收 ubifs 空间
# 3. 重启后：
#    mount -o remount,rw ubi0_0 /usr/tmp
#    cp /usr/plugin/osgi_new.img /usr/tmp/osgi.img && sync
#    mount -o remount,ro ubi0_0 /usr/tmp && reboot
# 4. 验证：cat /usr/plugin/startup.log /usr/plugin/root.log
```

## 从源码重建镜像

```sh
unsquashfs -d osgi_root images/osgi_orig.img
cp hook/java osgi_root/bin/java && chmod 755 osgi_root/bin/java
mksquashfs osgi_root osgi_new.img -comp xz -b 131072 -noappend
```

## 重编译 rootsh

```sh
aarch64-linux-gnu-gcc -static -O2 -s -o rootsh rootsh/rootsh.c
```

## 关键坑（详见 docs）

1. `/usr/plugin` 每次开机被递归 chown 成 `osgi:root`，**chown 清 setuid 位** ——
   setuid 文件必须放 `/userconfig`
2. 钩子以 osgi(58327) 身份运行、PATH 为空，`startup.sh` 须自行 `export PATH`
3. 删 osgi.img 后 ubifs 空间要重启才回收 → 替换流程天然两次重启
4. 该 busybox 无 `pkill/head/tail`，用 `pgrep`/`sed -n` 代替
5. 会失去 Java 插件（CMCCDPI/appcore/5080 接口）；要保留在 `hook/java` 末尾加
   `exec /usr/java/bin/java_renamed "$@"`
6. **别改 rootfs，别动引导程序** —— 前者破坏 RSA 签名直接变砖，后者破坏引导链
