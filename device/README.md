# 设备端组件

三个脚本，全部**只在运行期**工作，开机流程零动作。

| 脚本 | 作用 | 是否写 /system |
|---|---|---|
| `hbrew-enable-bridge` | 一次性创建 `/usr/local -> /data/harmonybrew/var/usrlocal` | 是（remount rw → ln -s → remount ro，**仅运行期**） |
| `hbrew-farm-build` | 生成/刷新命令农场（只写 `/data`） | 否 |
| `hbrew-farm-watch` | kegs 变化时刷新农场（只写 `/data`） | 否 |
| `hbrew-fix-rpath` | 审计 keg 的 RPATH（修复在构建侧） | 否 |

## 为什么是这种形态

`/usr/local/bin` 在这台设备的 PATH 里排**第一位**：

```
PATH=/usr/local/bin:/bin:/usr/bin
```

所以只要让 `/usr/local` 指向一个放在 `/data` 里的"精选命令农场"，
`brew install` 的任何东西就立刻可用 —— 不需要 source 环境、不需要改 PATH、
不需要开机时挂载。

农场必须**严格过滤**：

1. `/system/bin` 已存在的名字一律不发布（系统优先）；
2. 启动链命令硬编码排除（`sh` `mount` `ls` `cp` `cat` `chmod` …）；
3. `busybox` / `coreutils` 这类多 applet 包整体排除 —— 它们一个包就能
   接管 400+ 个系统命令名，正是第一次把设备搞到卡开机动画的元凶。

## 绝对禁止

**不要在开机流程（init job / hbrew-init / 任何 boot 阶段脚本）里做
`mount -o remount,rw /` 或写 `/system`。** 这会让 `/mnt` 的 tmpfs
superblock 被降级为只读，StorageDaemon 建不出 `/mnt/sandbox`，
`bootevent.boot.completed` 永不触发，设备永远停在开机动画。

## 用法

```bash
# 一次性：部署 + 建桥
hdc file send hbrew-enable-bridge /data/harmonybrew/sbin/
hdc file send hbrew-farm-build    /data/harmonybrew/sbin/
hdc file send hbrew-farm-watch    /data/harmonybrew/sbin/
hdc shell 'chmod 755 /data/harmonybrew/sbin/hbrew-*; \
           sed -i "s/\r$//" /data/harmonybrew/sbin/hbrew-*'
hdc shell /data/harmonybrew/sbin/hbrew-enable-bridge

# 可选：后台同步（安装在别处发生时也能自动跟上）
hdc shell 'setsid /data/harmonybrew/sbin/hbrew-farm-watch </dev/null >/dev/null 2>&1 &'

# 验收（必须截屏，不要只看窗口数）
hdc shell 'snapshot_display -f /data/local/tmp/s.jpeg'
hdc file recv /data/local/tmp/s.jpeg ./s.jpeg
```

正常：截图 ~166 KB 真实桌面，`bootevent.boot.completed=true`，无 `bootanimation` 进程。
卡死：截图 ~64 KB 全黑，`boot.completed` 未设置，`bootanimation` 一直存在。
