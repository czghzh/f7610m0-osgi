# 项目记忆（索引）

详细内容都在具体文件里，这里只做导航。要查某个主题，直接看「详情」那一栏指向的文件。

## 设备

- **设备 A（本地主力）**：中兴 F7610M0 光猫（ZX279131，AArch64，256MB SPI NAND），LAN 口 `192.168.1.1`，
  主机侧 `192.168.1.100`。内核 `#2 SMP Jul 4 2023`。
- **设备 B（远端）**：另一台 F7610M0，内核 `#72 SMP Aug 23 2022`。经跳板 `ssh wen@100.64.64.104`
  （Debian/armbian aarch64，Tailscale）→ 该机 LAN `192.168.1.2` → 再 telnet `192.168.1.1`。
  两台 `osgi.img` md5 **完全相同**（`e6f4ebdd…`），镜像可互换复用。
  注意设备 B 固件默认 conntrack 已是 30000（不是 16000），只有 buckets 偏低。
- **设备 C（第三台）**：跳板 `ssh wen@100.64.64.107`（Armbian aarch64，Tailscale），LAN `192.168.1.2`，
  光猫内核 `#72 Nov 29 2022`，**已部署完成并二次重启验证**。
  它的 `osgi.img` md5 `8fd834cd…` 与本地 `e6f4ebdd…` **不同** → 同型号不同固件镜像不能混用，
  已单独改造为 `osgi_c_new.img`（`06dd73ad…`，留在工作区）。
- **设备 D（第四台）**：跳板 `ssh wen@100.64.64.206`（Armbian aarch64，Tailscale），
  **LAN `192.168.1.151`**（不是 .2，容易搞错），光猫内核 `#2 Nov 29 2022`，已部署完成并二次重启验证。
  它的 `osgi.img` 与**设备 C 完全一致**（superblock + 多处偏移字节级相同），直接复用 `osgi_c_new.img`。
- **设备 E（第五台）**：跳板 `ssh wen@100.64.64.203`（Armbian aarch64，Tailscale），
  **LAN `192.168.1.15`**，光猫内核 `#2 Nov 29 2022`，已部署完成并二次重启验证。
  镜像与 C/D 完全一致，复用 `osgi_c_new.img`。部署前 conntrack count≈17000，是业务最忙的一台。
- **设备 F（第六台）**：跳板 `ssh wen@100.64.64.105`（Armbian aarch64，Tailscale），
  **LAN `192.168.1.17`**，光猫内核 `#2 Nov 29 2022`，已部署完成并二次重启验证。
  镜像与 C/D/E 一致，复用 `osgi_c_new.img`。跳板机根分区 96%（267M），最紧张。
- **设备 G（第七台，型号不同！）**：**ZXHN F7610U-C**，LAN `192.168.1.1`（直接可达），root/Zte521，
  内核 `#4 SMP Jan 27 2024`，SoC 同为 ZX279131 但**软件平台是中兴 CSP（cspd），不是 Java/OSGi**，
  **无 /usr/java、无 /usr/plugin、无 osgid** → F7610M0 的 java 钩子法**不适用**。
  rootfs 是 ramfs（可写、重启即丢），持久区只有 /userconfig(2MB jffs2)、/opt/cu/apps(ubifs 85MB 空闲)。
  详情见 `2026-10-31.md`。**telnet 不能并发**，必须串行。
  **开机自启已落地**：`/CuInform/CuInformLoader` 换壳（overlayfs upper 在 ubifs），
  链 `壳 → setsid hook.sh → user.sh → exec CuInformLoader.real`，uptime≈75 秒触发。
  部署件 `f7610u/boot/`，设备侧 `/opt/cu/apps/mystuff/`，参数见下面「统一参数」。
  **成果入库 `git@github.com:czghzh/f7610m0-osgi.git`**（`deploy/boot-f7610u/`）。
  注意别和 `czghzh/f7610u`（GPON 驱动源码）搞混——那个跟开机自启无关，别往里推。
  推送走 SSH（HTTPS 无凭据）。
- **统一参数（当前基准，2026-11-09 按最新 root.sh 对齐）**：`nf_conntrack_max=30720`、
  `nf_conntrack_buckets=30720`、`ip_local_port_range=1024-65535`、
  `nf_conntrack_tcp_timeout_established=3600`、`nf_conntrack_udp_timeout=20`、
  `nf_conntrack_udp_timeout_stream=40`。
  演进：10/30 是 30000/30208 + UDP 默认 30/180；11-03 收紧 20/40 → 11-04 撤回 →
  11-06 01:22 一度 40960/40960 → **11-06 20:10 定为上表**，四份 `root.sh` md5 全为
  `684deef6…`；2026-11-09 随 commit `b88aca0` 入库。跳板机（Armbian）侧 11-06 已设为
  20/40（`/etc/sysctl.d/99-custom.conf`）。
  其余 conntrack 超时参数一律保持机器默认，脚本里不出现、不读写。
  注意：设备上临时手改的值（如某台 max 65535、est 40）**重启即失效，不作为基准**，
  一律按上表部署；30000/30208 只作历史记录，详见主文档 §九。
- **大文件传输经验**：TFTP 极慢（停等协议，RTT 500ms 时只有 900 B/s），别用。
  改用自研静态工具 `tools/uploader`(设备→主机) / `downloader`(主机→设备) + `receiver.py`/`sender.py`，
  设备上已常驻 `/usr/plugin/{uploader,downloader}`。注意设备 `/tmp` 只有 15MB，
  大文件临时目录用 **`/upgtempfile`（100MB tmpfs）**。
- 登录：`telnet 192.168.1.1`，root / Zte521（三台相同）
- **设备 A 是故意离线的**（用户 2026-10-30 明确说过「不用管」）：`ip route` 只有 `192.168.1.0/24 dev br0`，
  `wansrcnat` 空，`pon`/`pon0` 收发全 0，`/proc/poninfo/statlastonmin` 全零。
  所以设备 A `ping` 外网报 `Network is unreachable` 属**预期状态**，不要再去排查光路。
  本机默认路由走 WiFi `192.168.16.1 dev wlp59s0`，不经过设备 A。
- 真正跑 PCDN 业务的是**设备 B**（conntrack count≈1500）。
- 设备 busybox 很精简：**无 head/tail/pkill/strings**，`df` 不支持 `-h`，`ping` 不支持 `-W`
- 常规操作前提醒：rootfs 是 RSA 签名的只读 jffs2，**不要往里写**

## 索引

| 主题 | 详情 |
|---|---|
| 光猫开机自启脚本（已实施并验证） | [`F7610M0_开机自启方案.md`](../../F7610M0_开机自启方案.md)，**唯一真相** |
| 钩子内 root 提权（rootsh）与 conntrack 参数集 | 同上文档 §5.5、§九 |
| 批量部署 / 镜像判定 / 参数集与变更记录 | 同上文档 §八、§九 |
| MTD 全分区备份（F7610U 等） | [`中兴光猫MTD全分区备份.md`](../../中兴光猫MTD全分区备份.md) |

2026-11-09 起，skill `zte-ont-boot-hook` 与 `zte-ont-mtd-backup` 已合并进上述文档并删除，
不再作为入口；备份脚本在 `tools/mtd-backup/`。

## 工作区里的常用件

> **2026-11-09 起内容入库 `git@github.com:czghzh/f7610m0-osgi`（public）。**
> 仓库侧布局：`images/`（**只有两个改造后镜像** osgi_new.img / osgi_c_new.img）、`tools/`（全部自研脚本）、
> `run-logs/`（部署日志）、`docs/`（文档副本）、`deploy/` `rootsh/`。
> **不入库**（体积大或另有出处）：原厂镜像（`/srv/tftp/osgi.img`、`osgi_c.img`）、
> 解包目录（`osgi_root/`、`osgi_root_c/`）、GPON 源码（独立仓库 `czghzh/f7610u`）。
> 工作区根是编辑源，仓库是入库副本 —— 改完工作区要 cp 过去再提交，否则重新分叉。

| 路径 | 用途 |
|---|---|
| `zt.py` | telnet 驱动（`printf 'cmd1\ncmd2\n' \| python zt.py`；`ZT_TMO` 控单命令超时） |
| `osgi_new.img` | 改造后的 osgi.img（java 已替换为钩子脚本） |
| `osgi_root/` | 上者的解包目录，要改内容就在这儿改完重打包 |
| `deploy/startup.sh` | 开机脚本模板（设备端 `/usr/plugin/startup.sh`） |
| `rootsh/` | setuid 提权器源码（部署在设备 `/userconfig/rootsh`） |
| `/srv/tftp/osgi.img` | **原始 osgi.img 备份**，恢复用 |

## 一句话总结现状

开机钩子（osgid→java 脚本→`/usr/plugin/startup.sh`）已生效，并通过
`/userconfig/rootsh`(setuid) 提权，在开机约 2 分钟内自动把 conntrack
max/buckets 调到 30720（日志 `/usr/plugin/root.log`）。
