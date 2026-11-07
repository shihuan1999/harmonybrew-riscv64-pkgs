NAME="cblas"
VERSION="0.3.28"
URL="https://github.com/OpenMathLib/OpenBLAS/archive/refs/tags/v0.3.28.tar.gz"
SHA256="f1003466ad074e9b0c8d421a204121100b0751c96fc6fcf3d1456bd12f8a00a1"
DESC="CBLAS: C interface to BLAS dense linear algebra (riscv64, from OpenBLAS)"
HOMEPAGE="https://www.netlib.org/blas/#_cblas"
BUILD_METHOD="custom"
# OpenBLAS is the practical CBLAS provider for riscv64: reference LAPACK needs
# a Fortran compiler we do not have, while OpenBLAS implements CBLAS natively.
# We only emit the CBLAS headers+static lib here; the kernels stay in the
# openblas package so the device holds a single BLAS copy.
_OB_ARGS="HOSTCC=gcc TARGET=RISCV64_GENERIC DYNAMIC_ARCH=0 NO_SHARED=1 NO_LAPACK=1 NOFORTRAN=1 USE_THREAD=0"
CUSTOM_BUILD="make \$_OB_ARGS libs netlib -j\$HBREW_JOBS"
INSTALL_CMD='set -e
  mkdir -p "$stage/lib" "$stage/include"
  cp libopenblas.a "$stage/lib/libcblas.a"
  cp libopenblas.a "$stage/lib/libblas.a"
  cp cblas.h "$stage/include/" 2>/dev/null || true
  cp -a ../lapack-netlib/CBLAS/include/cblas*.h "$stage/include/" 2>/dev/null || true
  cp -a ../lapack-netlib/CBLAS/include/*.h "$stage/include/" 2>/dev/null || true'
