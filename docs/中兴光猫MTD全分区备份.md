# 中兴光猫 MTD 全分区备份（已实测）

日期：2026-11-09　适用：ZX279xxx 平台（F7610U、F7600T 等），telnet `root / Zte521`

> 这篇原是 WorkBuddy skill `zte-ont-mtd-backup`，2026-11-09 合并进项目文档，skill 已删除。
> 配套脚本已搬到 `tools/mtd-backup/`。开机自启方案见主文档
> [F7610M0_开机自启方案.md](F7610M0_开机自启方案.md)。

## 适用场景

telnet 可达、BusyBox 带 `mtd_debug` 的中兴光猫/ONU，把所有 mtd 分区原样导出备份。
典型用途是刷机前留底。

## 配套脚本

| 文件 | 作用 |
|---|---|
| `tools/mtd-backup/tftpd.py` | 纯 Python 的 TFTP WRQ 接收端，替代 tftpd-hpa（sudo 要密码时装不了） |
| `tools/mtd-backup/zexec.py` | telnet 单条命令执行器 |
| `tools/mtd-backup/zbatch2.py` | 分块读、分片校验、按 offset 拼接成整分区并算整体 md5 |

**用前先改三个常量**：`tftpd.py` 的 `ROOT`、`zbatch2.py` 的 `OUT` 原本写死
`/home/wen/zte-backup/mtd`（工作目录外），`HOST/PORT` 写死 `192.168.1.1:23`；按实际
环境改成工作区内的输出目录和设备地址。`zexec.py` 用静默超时判结束，**只适合短命令**，
长命令必须按下面第 3 节的结束标记来。

## 0. 先摸清设备能力（必做，别照抄假设）

```sh
ip addr                     # 确认 br0 地址，判断宿主机所在网段
cat /proc/mtd               # 分区表：名字 + size + erasesize
df -k /tmp                  # ★ /tmp 常是 35MB tmpfs，决定分块大小
which nc dd tftp ftpput gzip md5sum mtd_debug
mtd_debug info /dev/mtdN    # 看 type/oobblock/oobsize
```

典型结果：**没有 dd、没有 nc、没有 base64、没有 scp**；有 `tftp`、`gzip`、`tar`、
`md5sum`、`hexdump`、`mtd_debug`。传输只能走 TFTP。

> 注意 `/tmp` 容量随机型变：F7610U 上是 35MB，F7610M0 上只有 15MB，
> 后者大文件临时目录要用 `/upgtempfile`（100MB tmpfs）。别把两处数字混用。

## 1. 通道：宿主机起极简 TFTP 接收端

`sudo` 通常要密码，别去装 tftpd-hpa，直接跑 `tftpd.py`。设备端：

```sh
tftp -p -l /tmp/c.bin -r mtdN_name.b000 192.168.1.100 6969
```

busybox tftp **没有 -b 选项**，固定 512B 块，实测 1.1–1.6 MB/s，256MB 约 4 分钟。

> TFTP 是停等协议，RTT 大时（跨跳板 500ms）会掉到约 900 B/s。
> 大镜像（osgi.img 之类）不要走这条路，用 `tools/uploader`/`downloader` 那套。

## 2. 分块读（关键，绕开 tmpfs 容量）

`mtd_debug read /dev/mtdN <offset> <size> <file>` 支持任意 offset/size。
**绝不要整块 dump 大分区**：写满 tmpfs 后 mtd_debug 会静默截断（表现是文件停在
34MB、md5 完全对不上），很容易误判成"分区坏了"。

- 块大小取 16MB（tmpfs 35MB，留够余量）
- 每块：read → md5sum（设备端）→ tftp 上传 → `rm -f` → 下一块
- 本地按 offset 递增顺序 `open(...,'ab')` 拼接，再算整体 md5

## 3. telnet 会话同步（最容易踩的坑）

**不能用"静默 N 秒"判定一条命令结束**：`mtd_debug` dump 大分区、`md5sum` 大分区
期间一行输出都没有，静默超时会让脚本提前发下一条命令，之后所有输出全部错位，
表现为"文件名对不上内容""md5 张冠李戴"。

正确做法——结束标记：

```sh
cmd; echo; echo __END""_7_0__; echo
```

- 搜索 `__END_7_0__`，等到它出现才算这条命令结束
- 标记必须用引号拼接写法，让**命令回显**里出现的是 `__END""_7_0__` 而不是
  `__END_7_0__`，否则回显本身就命中标记，立刻误判完成
- 长命令给 300–900 秒上限，超时才算异常

## 4. 校验（两级）

1. 每块：设备端 `md5sum /tmp/c.bin` vs 本地分片 md5，必须一致才拼接
2. 终检：设备端 `mtd_debug read` 全量到 tmpfs 后 md5（16MB 以下分区），
   和本地成品 md5 比对。注意 `md5sum /dev/mtdN` 在部分机型上会 RC=1 且无输出
   （大分区尤其明显），此时改用 `mtd_debug read` 落盘再 md5

## 5. bootrom（物理 0x0~0x20000）读不了是正常的

`mtd_debug read /dev/mtd13`、`cat /dev/mtd13`、`/dev/mtdblock13`、以及
`mtd_debug read /dev/mtd0 0 0x20000` **全部 EINVAL / EIO**，而 mtd0 从 0x20000
起读取完全正常 —— 内核驱动对该首块做了封禁，用户态无解。

不要在这里死磕。如实说明：这段是 BROM 引导块，刷机恢复不用它（uboot 从
mtd1 起），需要时从同型号固件包补。

`whole flash`(mtd0) 也不必单独导出：各分区 size 之和通常正好等于 mtd0
（本例 12 个分区合计 268304384 = 256MB − 128KB），逐个分区已完整覆盖。

## 6. 收尾

- 生成 `MD5SUMS.txt` + `README.md`（分区表、文件对应、缺口原因、恢复命令）
- 停掉临时 TFTP 服务（别留常驻），清理设备 `/tmp` 残留
- 后台起服务用 `setsid ... </dev/null >log 2>&1 &`，否则 ssh 被管道挂住
- `pkill -f xxx.py` 会匹配到自己这条命令，用 `pkill -f "[x]xx.py"`

## 恢复参考

```sh
tftp -g -r mtd7_kernel1.bin -l /tmp/k1.bin 192.168.1.100
mtd_debug erase /dev/mtd7 0 0x3000000
mtd_debug write /dev/mtd7 0 0x3000000 /tmp/k1.bin
```

> 大于 35MB 的分区同样要分块写，或先 `mount -o remount,size=256M /tmp`。
