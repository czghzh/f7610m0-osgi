# 项目记忆（索引）

详细内容都在具体文件里，这里只做导航。要查某个主题，直接看「详情」那一栏指向的文件。

## 设备

- 主力设备：中兴 F7610M0 光猫（ZX279131，AArch64，256MB SPI NAND），LAN 口 `192.168.1.1`，主机侧 `192.168.1.100`
- 登录：`telnet 192.168.1.1`，root / Zte521
- 常规操作前提醒：rootfs 是 RSA 签名的只读 jffs2，**不要往里写**

## 索引

| 主题 | 详情 |
|---|---|
| 光猫开机自启脚本（已实施并验证） | [`F7610M0_开机自启方案.md`](../../F7610M0_开机自启方案.md) |
| 钩子内 root 提权（rootsh）与 conntrack 30000 | 同上文档 §5.5 |
| 同上的可复用操作流程 | 技能 `~/.workbuddy/skills/zte-ont-boot-hook/SKILL.md` |

## 工作区里的常用件

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
max/buckets 调到 30000（日志 `/usr/plugin/root.log`）。
