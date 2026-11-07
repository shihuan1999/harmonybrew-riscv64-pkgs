# 为什么 apt 能装进系统路径，brew 同样做却卡开机动画？

> 2026-11-07 硬件实测复盘（K3 pico / OpenHarmony 6.1 / riscv64 musl）
> 全部结论都在设备上做过对照实验，可复现。

## 一句话结论

**apt 装的是"具体文件"，brew 之前被接成了"整个目录的优先级覆盖"。**
问题不在"写系统路径"这个动作，而在于三处**语义差异**被忽略：

1. **PATH 顺序** —— `/usr/local/bin` 排在 `/bin`（=`/system/bin`）**之前**，
   谁放进 `/usr/local/bin` 谁就赢过系统命令。
2. **busybox 是 400+ applet 的合集** —— 一个 busybox 链接进去，等于把
   `ls/cp/cat/ps/df/chmod/...` 全部接管，而这些正是 init、appspawn、
   StorageDaemon 启动时依赖的基础命令。
3. **`/system/lib64` 是全局默认库搜索路径** —— 往里放任何同名库，
   整个系统的每个进程都会优先加载它。

apt 世界里这三件事都不会发生：dpkg 不允许包间文件冲突，glibc 的
`/usr/lib/x86_64-linux-gnu` 里同名库由 dpkg 统一管理且 ABI 一致，
`/usr/local/bin` 在 Debian 里排在 `/usr/bin` **之后**。

## 一、实验证据

### 证据 1：纯净系统启动完全正常

移除全部 brew 注入（`/usr/local/bin` 农场 130 条、`/system/bin` 44 条、
`/system/lib64` 43 条），禁用 brewboot 后重启：

```
/mnt  = tmpfs (rw)          ← 正常
窗口  = 11 个，有焦点       ← 桌面正常
ls    = toybox 0.8.12       ← 系统命令正常
```

### 证据 2：只要 `/usr/local/bin` 有农场，系统命令即被劫持

`/usr/local/bin` 在 PATH 第一位。v1-v5 部署时该目录有 130 条链接，
其中 busybox 的 applet 覆盖了系统核心命令：

```
# 农场存在时
$ ls --version
BusyBox v1.37.0 (2026-10-17) multi-call binary.   ← 被 busybox 接管
$ which ls
/usr/local/bin/ls

# 清掉农场后
$ ls --version
toybox 0.8.12                                      ← 系统原生
```

直接复现（不改文件系统，只改 PATH）：

```
$ PATH=/data/harmonybrew/bin:/system/bin:/bin sh -c 'ls --version'
ls: unrecognized option: version                   ← busybox 版 ls 生效
$ ls --version                                     ← 原 PATH 下
toybox 0.8.12
```

### 证据 3：busybox 的接管面

`brew install busybox` 会往 `bin/` 铺 **400+ 个 applet 链接**，
其中与系统核心工具重名的包括：

```
arch ash base32 base64 cat chattr chgrp chmod chown clear cp cpio date dd
df dmesg dnsdomainname echo env expr false find free grep gunzip gzip hostname
id ifconfig kill less ln ls md5sum mkdir mknod mktemp more mount mv nc netstat
nohup od patch ping printf ps pwd readlink realpath rm rmdir sed sh sleep sort
stat stty sync tar tee test time top touch tr true tty umount uname uniq
uptime wc wget which whoami xargs ...
```

`init` 的 job 脚本（`mkdir`/`chown`/`mount`）、`appspawn`、`storage_daemon`
在启动早期全部通过这些命令工作。任何一个被换成 ABI/行为不同的版本，
启动链条就断在某一环 —— 表现为 `StorageDaemon` 建目录 `EROFS/ENOENT`、
`/mnt` 保持只读、`/mnt/sandbox` 建不出来、应用无法 fork、
**屏幕停在开机动画**。

### 证据 4：`/system/lib64` 注入库的后果

把 43 个 brew 库链到 `/system/lib64` 后，系统库被影子化：

```
SHADOWED: libcrypto.so.3  -> /data/harmonybrew/lib/libcrypto.so.3
SHADOWED: libssl.so.3     -> /data/harmonybrew/lib/libssl.so.3
SHADOWED: libsqlite3.so.0 -> /data/harmonybrew/lib/libsqlite3.so.0
```

镜像自带的是 `libcrypto.so.1.1`/`libssl.so.1.1` 系列，brew 的是
OpenSSL 3 的 `.so.3`。系统服务解析到 `.so.3` 会符号缺失或行为不符。
实测同样卡在开机动画。

### 证据 5：不是我的 `remount` 动作

在运行中的系统上原样执行 brewboot 里的动作：

```
$ mount -o remount,rw / && mount -o remount,ro /
$ mount | grep ' on /mnt '
tmpfs on /mnt type tmpfs (rw,...)      ← /mnt 不受影响
```

根分区 remount 不会连带 `/mnt`。早期的怀疑排除。

## 二、apt 与 brew 的对照表

| 维度 | apt (Debian) | 我之前的 brew 接法 | 后果 |
|---|---|---|---|
| 安装粒度 | 单文件铺进 `/usr/bin` | 目录级符号链接农场 | 一个农场=400+命令全集 |
| PATH 优先级 | `/usr/local/bin` 在 `/usr/bin` **之后** | `/usr/local/bin` 在 `/bin` **之前** | brew 无条件赢 |
| 冲突处理 | dpkg 拒绝文件冲突 | 直接 ln -sf 覆盖 | 系统命令被静默替换 |
| 库路径 | dpkg 统一管 `/usr/lib/*`，ABI 一致 | 塞进 `/system/lib64` | 全系统库被影子化 |
| 多版本 | `update-alternatives` | 农场无版本概念 | 无法回退 |
| 卸载 | dpkg 精确删自己装的 | 农场需手动重建 | 易残留（本次残留130条） |

**根本差异：apt 的世界里"包 = 一组具体文件 + 冲突检查"；
brew 默认"包 = 一个前缀目录"，而这个前缀目录被当作 PATH 最高优先级
整体暴露出去，等于把 brew 的整个命令行生态置于系统生态之上。**

## 三、正确做法（v9 定案）

原则：**学 apt —— 只暴露"包自己的文件"，绝不覆盖系统，绝不改库搜索路径。**

### 3.1 命令：按包精确发布到 `/system/bin`，且跳过所有冲突

```
/system/bin/<cmd> -> /data/harmonybrew/bin/<cmd>   （仅当 /system/bin/<cmd> 不存在）
```

- `/system/bin` 本来就在 PATH 里（`/bin` 是它的符号链接），**不需要动 PATH**
- 逐条比对，系统已有同名文件一律跳过（system wins）
- 只建**单文件符号链接**，`brew uninstall` + reap 精确回收
- 悬空链接每次巡检自动清理

### 3.2 **永不发布库到 `/system/lib64`**

brew 二进制靠**编译期烘焙的 rpath** 找自己的库：

```
-Wl,-rpath,/data/harmonybrew/lib
```

这是私有路径，只影响这个二进制，不污染全局搜索。
**没有 rpath 的包是打包缺陷**（本次发现 jq 就是），必须在打包侧修复，
而不是把库塞进系统路径。

### 3.3 永不使用 `/usr/local/bin` 农场

`/usr/local/bin` 在 PATH 第一位且是全局的。任何"整个目录"级别的暴露
都会重演本次事故。`hbrew-systemlink` v2 会主动清除历史残留。

### 3.4 busybox 这类"多 applet"包特殊处理

`busybox`/`coreutils` 等提供大量与系统重名命令的包，默认**只装不链**：
包内文件在 `/data/harmonybrew/Cellar/...` 可用（通过
`/data/harmonybrew/bin/busybox` 显式调用或 `busybox ls`），
不参与系统路径发布。需要特定 applet 时用 `busybox <applet>` 显式调用。

## 四、复现与验证命令

```bash
# 检查是否有劫持（应全部为 0）
ls -la /system/bin     | grep -c harmonybrew
ls -la /system/lib64   | grep -c harmonybrew
ls /usr/local/bin 2>/dev/null | wc -l
ls -l /usr/local 2>/dev/null            # 不应存在

# 系统命令身份（应为 toybox）
ls --version | head -1

# 健康度
mount | grep ' on /mnt '                # 应为 (rw)
hidumper -s WindowManagerService -a '-a' | grep -E 'Focus window|total window'
```

## 五、给后续维护者的红线

1. **不要**把任何 brew 目录整体挂载/链接到 `/usr/local/*`。
2. **不要**把任何 brew 库放进 `/system/lib64`、`/lib`、`/usr/lib`。
3. **可以**把**单个**、**系统没有的**命令链进 `/system/bin`。
4. **必须**给每个 brew 包烘焙 `-Wl,-rpath,/data/harmonybrew/lib`。
5. 启动链依赖的命令（`sh` `mount` `mkdir` `chown` `ps` `ls` `cp` 等）
   永远不参与发布——即使系统里"看起来没有"。

---

## 六、补充：RPATH 是第二个"隐形杀手"（2026-11-07 实测）

零步骤发布之后还有一个独立缺陷，和 PATH 无关：

```
$ jq --version
Error loading shared library libjq.so.1: (needed by /system/bin/jq)
```

原因不是库缺失（`libjq.so.1` 就在 keg 里），而是 **DT_RPATH 被烘成了构建机路径**：

```
$ readelf -d .../jq/1.8.1/bin/jq | grep RPATH
Library rpath: [/home/heshihuan/WorkSpace/harmonybrew-port/out/stage-jq/jq/1.8.1/lib]
```

这是 `./configure --prefix=$d` 时 `$d` 为 staging 目录的必然结果。apt 不会
出现这个问题，因为 Debian 的构建流水线统一用 `-Wl,-rpath` 指向最终安装
前缀，并且 dpkg 装完后会跑 `ldconfig`。

### 修法：打包时重写 RPATH（纯 Python，无需 patchelf）

`elf_rpath.py` 直接改 `.dynstr` 里 RPATH 字符串（新串更短时原地覆盖）：

```bash
$ python3 elf_rpath.py --set bin/jq '/data/harmonybrew/lib:/data/harmonybrew/Cellar/jq/1.8.1/lib'
OK bin/jq: rewrote in place (69 -> 60 bytes)
$ jq --version
jq-1.8.1
```

`hbrew-build.sh` 已把这一步做成标准阶段（3b）：打完 bottle 后扫描所有 ELF，
凡 RPATH 不指向 `/data/harmonybrew` 的一律改写，然后重新打包。

### 规则补充（第 6 条红线）

6. **每个 bottle 发布前必须校验 RPATH**：
   `python3 elf_rpath.py --check <bin> /data/harmonybrew`
   输出 BAD-RPATH / NO-RPATH 的包不允许发布。
