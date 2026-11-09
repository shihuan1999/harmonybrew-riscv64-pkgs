# Harmonybrew 科学计算包仓库

面向 **OpenHarmony / K3 pico（riscv64 musl）** 的 Harmonybrew 二进制包集合，
以及把这套包**交叉编译 + 打包 + 安装**的全套工具。

一次 `./scripts/build.sh --all`，就能从源码编译出可直接 `brew install` 的
`riscv64_ohos` bottle。

## 这个仓库解决什么问题

在 OpenHarmony 设备上用 brew 装包，有两个反直觉的坑（都在真机上复现过）：

1. **不要把 brew 目录整体暴露到 PATH 前面**
   `/usr/local/bin` 排在 `/bin` 之前。把 brew 的 bin 目录整体链/挂到那里，
   `busybox` 之类的包会一次性接管 `ls/cp/cat/ps/df/mount/...`，
   而 init、appspawn、StorageDaemon 恰好靠这些命令工作 ——
   结果是 **/mnt 挂不上、沙箱建不出来、设备永远停在开机动画**。

2. **不要把 brew 的库放进 `/system/lib64`**
   那是整个系统的默认库搜索路径。放进去的 `libssl.so.3`、`libcrypto.so.3`
   会影子化镜像自带的 `libssl.so.1.1` 等，同样卡死启动。

本仓库采用 **apt 的做法**：

| 项 | 做法 |
|---|---|
| 命令 | 逐个文件链到 `/system/bin`，**系统已有同名文件一律跳过** |
| 库 | **永不发布**。二进制靠编译期 `-Wl,-rpath,/data/harmonybrew/lib` 找自己的库 |
| 冲突 | 系统优先，绝不覆盖 |
| 卸载 | `brew uninstall` 后自动回收悬空链接 |
| RPATH | 构建后统一重写为设备路径（见下） |

详见 [docs/WHY-APT-WORKS-BREW-BROKE.md](docs/WHY-APT-WORKS-BREW-BROKE.md)。

## 快速开始

### 1. 准备工具链

```bash
# SpacemiT musl OHOS 交叉工具链（riscv64-unknown-linux-musl-*）
export HBREW_TC=$HOME/WorkSpace/spacemit-toolchain-linux-musl-x86_64-oh-20260630
```

### 2. 构建全部包

```bash
./scripts/fill-sha256.sh      # 首次：下载源码并回填 sha256
./scripts/build.sh --all      # 编译 + 打包所有 recipe
```

产物在 `out/`：

```
out/gsl-2.8.riscv64_ohos.bottle.tar.gz
out/gsl.rb
out/INDEX.txt                 # name version sha256
```

### 3. 单包构建

```bash
./scripts/build.sh recipes/gsl.sh
./scripts/build.sh gsl              # 简写，自动补 recipes/ 与 .sh
```

### 4. 在设备上安装

```bash
# formula 从 Release 拉 bottle
curl -L -o /tmp/gsl.rb https://github.com/<owner>/<repo>/releases/download/bottles/gsl.rb
brew install /tmp/gsl.rb

gsl-randist --help                  # 装完即可用，无需 source 任何环境
```

## 写一个新 recipe

recipe 是普通 shell 文件，声明元数据 + 构建方式即可：

```bash
NAME="mylib"
VERSION="1.2.3"
URL="https://example.org/mylib-1.2.3.tar.gz"
SHA256="..."                       # 可留空，fill-sha256.sh 会回填
DESC="What it does"
HOMEPAGE="https://example.org/mylib"
DEPS="openblas"                    # 空格分隔

BUILD_METHOD="cmake"               # autoconf | cmake | make | custom
CMAKE_ARGS="-DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF"
```

四种 `BUILD_METHOD`：

| 方法 | 行为 |
|---|---|
| `autoconf` | `./configure --host=$HOST --prefix=$stage --disable-shared` → `make` → `make install` |
| `cmake` | 交叉工具链 + `CMAKE_INSTALL_PREFIX=$stage`，静态库 |
| `make` | `make PREFIX=$stage` → `make install PREFIX=$stage` |
| `custom` | 自己写 `CUSTOM_BUILD` 与 `INSTALL_CMD` |

特殊场景用 `POST_BUILD()` 函数做二次修正。

## 交叉编译常见的坑（本仓库已处理）

| 现象 | 原因 | 处理 |
|---|---|---|
| `-march=native: ISA string must begin with rv32/rv64` | OpenBLAS 探测主机 CPU | `TARGET=RISCV64_GENERIC` + `HOSTCC=gcc` |
| `VerifyFortranC` 链接失败 | LAPACK 要跑目标程序、且无 Fortran 编译器 | 改用 OpenBLAS 提供的 CBLAS |
| `zlib: unknown option --host` | zlib 自定义 configure 只认 `CHOST` | `CHOST=$HOST ./configure` |
| `Error loading shared library libjq.so.1` | RPATH 被烘成构建机 staging 路径 | `scripts/elf_rpath.py` 打包后重写 |
| 下载超时 | 非交互 shell 不读 `~/.bashrc`，代理丢失 | 构建脚本自动探测并 export 代理 |

## RPATH 修复（关键）

构建机上 `./configure --prefix=<staging>` 会把 **staging 绝对路径**写进
`DT_RPATH`，设备上根本不存在，于是二进制找不到自己的库。

`scripts/elf_rpath.py` 是纯 Python 的 ELF 改写器（不需要 patchelf）：

```bash
python3 scripts/elf_rpath.py --get   bin/jq
python3 scripts/elf_rpath.py --set   bin/jq '/data/harmonybrew/lib:/data/harmonybrew/Cellar/jq/1.8.1/lib'
python3 scripts/elf_rpath.py --check bin/jq /data/harmonybrew
```

`build.sh` 在打包前自动对所有 ELF 执行这一步，然后重新打包。

## 设备端零步骤安装

设备端只做一件事：把 `/usr/local` 指向 `/data` 里的命令农场（一次性，运行期）。

```bash
# 1) 推送脚本
hdc file send device/hbrew-farm-build    /data/harmonybrew/sbin/
hdc file send device/hbrew-enable-bridge /data/harmonybrew/sbin/
hdc file send device/hbrew-farm-watch    /data/harmonybrew/sbin/
hdc shell 'chmod 755 /data/harmonybrew/sbin/hbrew-*; 
           sed -i "s/$//" /data/harmonybrew/sbin/hbrew-*'

# 2) 建立桥接（创建 /usr/local -> /data/harmonybrew/var/usrlocal）
hdc shell /data/harmonybrew/sbin/hbrew-enable-bridge

# 3) 让后续安装自动同步（可选）
hdc shell 'setsid /data/harmonybrew/sbin/hbrew-farm-watch </dev/null >/dev/null 2>&1 &'
```

之后：

```bash
brew install tree && tree --version      # 立刻可用（/usr/local/bin 在 PATH 第一位）
brew uninstall tree && which tree        # 立刻消失
ls --version                             # 仍是 toybox，系统命令没被劫持
```

### ⚠️ 唯一红线：不要在开机流程里碰 /system

`hbrew-enable-bridge` 会 remount `/` 一次（创建那个符号链接）。**只能在对
已完全启动的设备执行**。任何在 boot 阶段（init job、hbrew-init、brewboot）
做 `remount,rw /` 或写 `/system` 的行为都会让设备永远停在开机动画：

```
开机早期 remount,rw / 并写入 /system
  → /mnt 的 tmpfs superblock 被降级为只读
  → StorageDaemon 建不出 /mnt/sandbox
  → 应用无法 fork，bootevent.boot.completed 永不触发
  → bootanimation 永不退出（屏幕亮着，但没有任何画面）
```

这个结论在真机上复现了两次，详见
[docs/WHY-APT-WORKS-BREW-BROKE.md §7](docs/WHY-APT-WORKS-BREW-BROKE.md)。

### 验收：必须截屏，不能看窗口数

```bash
hdc shell 'snapshot_display -f /data/local/tmp/s.jpeg'
hdc file recv /data/local/tmp/s.jpeg ./s.jpeg     # 然后看图
```

卡死时截图是 **64 KB 纯黑**；正常时是 **166 KB 真实桌面**。
`total window num: 3` 曾经骗过我一次——窗口对象被创建不等于画面被渲染。

## 目录结构

```
scripts/
  build.sh           交叉构建 + 打包 + 生成 formula
  fill-sha256.sh     下载源码并回填 sha256
  gen_recipes.py     批量生成 recipe（数据驱动）
  elf_rpath.py       纯 Python ELF RPATH 读写
recipes/             每个包一个 .sh
device/              设备端零步骤安装组件
  hbrew-enable-bridge  一次性创建 /usr/local -> /data 农场链接（运行期，非开机）
  hbrew-farm-build     生成/刷新命令农场（只写 /data，系统同名一律跳过）
  hbrew-farm-watch     kegs 变化时刷新农场（只写 /data，绝不 remount）
  hbrew-fix-rpath      审计 keg 的 RPATH（修复在构建侧做）
docs/
  WHY-APT-WORKS-BREW-BROKE.md   为什么 apt 行、brew 那样做会卡开机动画
out/                 构建产物（不入库）
src/                 源码缓存（不入库）
```

## 当前包集合

数学/线性代数、FFT/信号处理、统计与优化、数据格式（HDF5/NetCDF）、
压缩、C++ 科学计算基础设施等，共 60+ 个 recipe，见 `recipes/`。

构建状态见 `out/INDEX.txt`。
