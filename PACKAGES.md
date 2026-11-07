# 已构建并发布的气泡包（53 个）

全部可在任意 K3 pico / OpenHarmony riscv64 设备上 `brew install`，
下载地址：`https://github.com/shihuan1999/harmonybrew-riscv64-pkgs/releases/download/bottles/<name>-<ver>.riscv64_ohos.bottle.tar.gz`

## 数学与线性代数
| 包 | 版本 | 说明 |
|---|---|---|
| openblas | 0.3.28 | BLAS 密集线性代数内核（RV64GC 通用） |
| cblas | 0.3.28 | CBLAS C 接口（复用 OpenBLAS 内核） |
| eigen | 3.4.0 | C++ 模板线性代数（矩阵/向量/求解器） |
| gsl | 2.8 | GNU 科学计算库（数值例程全集） |
| gsl-stats / gsl-interp | 2.8 | GSL 统计/插值子集构建 |
| superlu | 6.0.1 | 稀疏线性方程组直接解法 |
| suitesparse | 7.8.3 | 稀疏矩阵算法族（AMD/CHOLMOD/UMFPACK） |
| amgcl | 1.4.4 | 代数多重网格求解器（header-only） |
| spectra | 1.0.1 | 大规模特征值问题（header-only） |
| nlopt | 2.8.0 | 非线性优化（多种算法） |
| optimlib | 1.0 | C++ 数值优化例程 |
| lbfgspp | 0.3.0 | L-BFGS / L-BFGS-B 求解器 |
| sundials | 7.1.1 | ODE/DAE 与非线性求解器 |
| tinyspline | 0.6.0 | NURBS/B 样条插值 |

## FFT 与信号处理
| 包 | 版本 | 说明 |
|---|---|---|
| fftw | 3.3.10 | 快速傅里叶变换（多线程、静态） |
| kissfft | 131.1.0 | 简洁定点/浮点 FFT |
| pffft | 1.0 | SIMD 友好小型 FFT |
| soxr | 0.1.3 | 高质量采样率转换 |
| samplerate | 0.2.2 | 音频采样率转换 |
| libsndfile | 1.2.2 | 音频文件读写 |
| libmseed | 2.19.8 | miniSEED 地震数据格式 |

## 数值/几何优化
| 包 | 版本 | 说明 |
|---|---|---|
| ceres | 2.2.0 | 非线性最小二乘（配方已就绪） |
| g2o | 20241228 | 图优化（SLAM/BA） |
| glm | 1.0.1 | 图形/几何数学库（header-only） |

## 数据格式与 IO
| 包 | 版本 | 说明 |
|---|---|---|
| hdf5 | 1.14.4 | HDF5 层次化科学数据格式 |
| netcdf | 4.9.3 | NetCDF 数组型科学数据（经典格式） |
| cgns | 4.4.0 | CFD 通用标注系统（配方已就绪） |
| json | 3.11.3 | JSON for Modern C++ |
| rapidjson | 1.1.0 | 高速 JSON 解析 |
| cjson | 1.7.18 | 超轻量 C JSON |
| yaml-cpp | 0.8.0 | YAML 解析/生成 |
| pugixml | 1.14 | 轻量 XML 解析 |
| tinyxml2 | 10.0.0 | 简洁 XML 解析 |
| cereal | 1.3.2 | C++11 序列化 |
| utf8proc | 2.9.0 | UTF-8 文本处理 |
| double-conversion | 3.3.0 | 快速浮点/十进制互转 |

## 压缩
| 包 | 版本 | 说明 |
|---|---|---|
| zlib | 1.3.1 | 通用压缩库 |
| zstd | 1.5.6 | Zstandard 高速压缩 |
| lz4 | 1.10.0 | 极速压缩 |
| xz | 5.6.3 | LZMA2 压缩 |
| bzip2 | 1.0.8 | 块排序压缩器 |

## C++ 基础设施
| 包 | 版本 | 说明 |
|---|---|---|
| fmt | 11.0.2 | 现代 C++ 格式化 |
| spdlog | 1.15.0 | 高速日志 |
| cli11 | 2.4.2 | 命令行解析 |
| argparse | 3.1 | 现代 C++ 参数解析 |
| highway | 1.2.0 | 可移植 SIMD |
| xsimd | 13.0.0 | SIMD 内在函数封装 |
| xtl | 0.7.7 | xtensor 基础工具 |
| expat | 2.6.4 | XML 解析器 |

## 工具与脚本
| 包 | 版本 | 说明 |
|---|---|---|
| gnuplot | 6.0.2 | 命令行绘图 |
| units | 2.23 | 单位换算计算器 |
| parallel | 20241022 | 并行作业执行（参数扫描） |
| perl | 5.40.0 | Perl 脚本语言（生信流程） |
| tinyexpr | 1.0 | 微小表达式解析求值 |
| kissfft | — | 见上 |

## 安装示例

```bash
# 方式 1：从 Release 直接装
curl -fsL -o /tmp/gsl.rb \
  https://github.com/shihuan1999/harmonybrew-riscv64-pkgs/releases/download/bottles/gsl.rb
brew install /tmp/gsl.rb
gsl-randist 12345 10 gaussian 1 2      # 立即使用

# 方式 2：建本地 tap（推荐，可 brew upgrade）
mkdir -p $HOMEBREW_PREFIX/Library/Taps/ghbrew/homebrew-pkgs/Formula/g
cp /tmp/gsl.rb  $HOMEBREW_PREFIX/Library/Taps/ghbrew/homebrew-pkgs/Formula/g/
brew install ghbrew/pkgs/gsl
```

> 设备直连 GitHub 受限时，可在能联网的机器上下载 bottle，推到
> `/data/brewpack/store/`，把 formula 的 `root_url` 改成
> `file:///data/harmonybrew/home/.cache/Homebrew/downloads` 后安装（离线方案）。
