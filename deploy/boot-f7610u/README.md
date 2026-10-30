# F7610U-C 开机自启（已落地，2026-10-31）

和 F7610M0 不是一套方案。F7610M0 靠替换 `/usr/java/bin/java` 让 osgid 拉起；
F7610U-C 是中兴 CSP 平台，**没有 java、没有 osgid、没有 /usr/plugin**，那条路不通。

## 用的是哪个钩子

**`/CuInform/CuInformLoader` 换壳。**

- `/CuInform` 是 overlayfs，`upperdir=/opt/cu/apps/CuInformUpper`（mtd12 ubifs，持久、可写）
- `CuInformLoader` 由主控进程 `pc`(pid 245) 直接 exec，不在任何 init 脚本里
- 覆盖它就等于在持久层加了一层壳，重启保留

**触发链**：`pc → /CuInform/CuInformLoader(壳) → setsid hook.sh → user.sh`，
壳最后 `exec CuInformLoader.real`，原插件链（CuInformLoader.real → CuInform → CuInform-inner）完全不受影响。

**触发时刻**：uptime ≈ 70 秒（三次冷启动实测 70.64 / 70.68 / 71.37 秒，很稳定）。

## 设备上的文件

| 路径 | 说明 |
|---|---|
| `/CuInform/CuInformLoader` | 367B shell 壳，md5 `84e080864c4ad63450d06dc9073ec53e` |
| `/CuInform/CuInformLoader.real` | 原 ELF，md5 `fde078ffeec505f3b2d38ff4cd2f1a4d` |
| `/opt/cu/apps/mystuff/hook.sh` | 开机入口，日志覆盖写、跑完自杀不留僵尸 |
| `/opt/cu/apps/mystuff/user.sh` | **要改就改这个**，放所有 sysctl 设置 |
| `/opt/cu/apps/mystuff/boot.log` | 只保留最近一次开机的一段 |
| `/opt/cu/apps/mystuff/rollback.sh` | 一键回退 |
| `/opt/cu/apps/mystuff/CuInformLoader.orig` | 原 ELF 留底 |
| `/usr/pre_plugin/pre_CuInform_F7610U/CuInformLoader` | 只读 squashfs 里的原版，永远可恢复 |

## 目标参数

只改这四个：

| 参数 | 原值 | 目标值 |
|---|---|---|
| nf_conntrack_max | 16000 | **30000** |
| nf_conntrack_buckets | 3300 | **30208** |
| ip_local_port_range | 32768 61000 | **1024 65535** |
| nf_conntrack_tcp_timeout_established | 86400 | **3600** |

其余 conntrack 参数一律保持机器默认，脚本里不出现、不读写。

## 坑（都已解决，改脚本时别踩回去）

1. **上传不能用 base64**：设备 busybox 没有 base64 / xxd / uuencode。
   `install.sh` 的做法是主机起 `python3 -m http.server 8901`，设备 `wget` 拉到 `/upgtempfile`（tmpfs，100MB）再拷进去。
   直接 `echo '<b64>' | base64 -d` 会静默生成 0 字节文件。

2. **cspd 会回刷参数**：我们设的那几项也可能被后来的进程覆盖，所以 user.sh 末尾挂了一个
   **一次性**延时复查（sleep 90 后检查并补设，做完就退出，不常驻）。boot.log 里的「延时复查」段就是它。

3. **overlayfs 里不能用 mv**：`mv` 改名会因 copy-up + whiteout 丢文件。
   必须 `cp` 复制一份再 `rm` 原文件。

4. **hook.sh 必须用 `setsid` 起，不能 `&`**：
   壳最后要 `exec` 成常驻的 `CuInformLoader.real`，它永远不会 wait 子进程。
   若用 `hook.sh &`，hook.sh 跑完就变成挂在它名下的 **Z 僵尸**（`<defunct>`，
   PPid 指向 `CuInformLoader.real`），而且因为它被移进了 cgroup 的 cgroup.procs，
   在 init 里 kill 也清不掉。改用 `setsid hook.sh </dev/null >/dev/null 2>&1`
   让它脱离进程树，跑完直接消失。hook.sh 里另有 `kill -9 $$` 兜底。

## 操作

本目录是仓库里的副本，实际工作目录在 `WorkBuddy/f7610m0/f7610u/boot/`。

```sh
cd <工作区>/f7610m0/f7610u/boot

bash install.sh              # 安装/更新（会就地空跑一次让参数立刻生效）
bash install.sh --restore    # 回退，然后必须重启一次
```

改参数只改 `user.sh`，然后跑 `install.sh`。**不用重启**——install.sh 会立刻执行一遍。

推仓库（HTTPS 没配凭据，必须走 SSH）：

```sh
cd /home/wen/WorkBuddy/f7610m0/f7610m0-osgi
git add deploy/boot-f7610u && git commit -m "..."
git push origin main
```

## 验证

```sh
# 重启后
cat /opt/cu/apps/mystuff/boot.log
# 看 uptime=7x 那一行 + 「延时复查」段的最终值
```

## 注意

- 设备 **telnet 不能并发**，第二个会话会互相踢（报「没有到主机的路由」）
- `zt.py` 要用 venv python：`/home/wen/.workbuddy/binaries/python/envs/default/bin/python`
- 设备没有 `dd`、没有 `base64`；`head` 也没有
- rootfs 是内存 ramfs，改 `/etc` 重启即丢；持久区只有 `/userconfig`(1.5MB) 和 `/opt/cu/apps`(79MB)
