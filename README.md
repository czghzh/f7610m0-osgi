# f7610m0-osgi — 中兴光猫开机自启方案

不碰 rootfs（RSA 签名只读 jffs2）、不碰 U-Boot，实现开机自动执行自定义脚本，
并可在钩子内提权到 root（已冷启动验证）。

涵盖两种平台，**方案不通用**，别混：

| 型号 | 平台 | 钩子 | 目录 |
|---|---|---|---|
| F7610M0 | Java/OSGi（osgid） | 替换 `/usr/java/bin/java` | 本页（根目录） |
| F7610U-C | 中兴 CSP（cspd） | 替换 `/CuInform/CuInformLoader` | [`deploy/boot-f7610u/`](deploy/boot-f7610u/README.md) |

完整原理、步骤、踩坑记录见：

- F7610M0 → **[docs/F7610M0_开机自启方案.md](docs/F7610M0_开机自启方案.md)**
- F7610U-C → **[deploy/boot-f7610u/README.md](deploy/boot-f7610u/README.md)**

## 原理一句话（F7610M0）

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
| `deploy/boot.d/root.sh` | root 身份开机脚本模板（设备端 `/usr/plugin/boot.d/root.sh`，含 conntrack 30720/30720 + UDP 20/40） |
| `images/osgi_new.img` | **改造后镜像**（A/B 机型，java 已替换，可直接部署） |
| `images/osgi_c_new.img` | **改造后镜像**（C/D/E/F 机型，`06dd73ad…`，可直接部署） |
| `tools/` | 自研 telnet 驱动、批量部署/巡检脚本、MTD 备份（`tools/mtd-backup/`） |
| `tools/zt.py` | telnet 批量驱动（`printf 'cmd1\ncmd2\n' \| python zt.py`） |
| `run-logs/` | 各设备批量部署/校验/重启日志（2026-11-06 那一批） |
| `deploy/boot-f7610u/` | **F7610U-C** 整套部署件（换壳脚本 + 安装/回退 + 说明），见该目录 README |
| `docs/` | 完整方案文档（主文档 + MTD 备份） |
| `.workbuddy/memory/` | 项目工作记忆快照（MEMORY.md 索引 + 当日记录） |

**仓库不收录**（体积大或另有出处，只在本地主机侧保留）：

| 内容 | 本地位置 |
|---|---|
| 原厂 osgi.img 备份 | `/srv/tftp/osgi.img`（A/B）、`osgi_c.img`（C/D/E/F，`8fd834cd…`） |
| 镜像解包目录 | `osgi_root/`、`osgi_root_c/` |
| ZX279131 GPON 驱动 + ImmortalWrt 移植源码 | `f7610u/` —— **独立仓库** `github.com/czghzh/f7610u` |

> ⚠️ 本仓库为 **public**，`tools/` 与 `run-logs/` 中含 telnet 密码与跳板/Tailscale 地址，
> 按项目决定原样入库以便完整复现。如需轮换密码请同步更新对应脚本。

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

原厂镜像和解包目录不入库，本地留着。重建流程（在主机侧做）：

```sh
# A/B 机型：原厂镜像 /srv/tftp/osgi.img（md5 e6f4ebdd…）
unsquashfs -d osgi_root /srv/tftp/osgi.img
cp hook/java osgi_root/bin/java && chmod 755 osgi_root/bin/java
mksquashfs osgi_root osgi_new.img -comp xz -b 131072 -noappend -no-xattrs

# C/D/E/F 机型：原厂镜像 osgi_c.img（md5 8fd834cd…）
unsquashfs -d osgi_root_c osgi_c.img
cp hook/java osgi_root_c/bin/java && chmod 755 osgi_root_c/bin/java
mksquashfs osgi_root_c osgi_c_new.img -comp xz -b 131072 -noappend -no-xattrs
```

重建后用 md5 对比仓库里的 `images/osgi_new.img` / `images/osgi_c_new.img` 校验一致性。

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
