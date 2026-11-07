NAME="openblas"
VERSION="0.3.28"
URL="https://github.com/OpenMathLib/OpenBLAS/archive/refs/tags/v0.3.28.tar.gz"
SHA256="f1003466ad074e9b0c8d421a204121100b0751c96fc6fcf3d1456bd12f8a00a1"
DESC="Optimized BLAS library: dense linear algebra kernels (riscv64)"
HOMEPAGE="https://www.openblas.net/"
BUILD_METHOD="custom"
# Cross-compiling OpenBLAS needs several knobs pinned:
#  1. TARGET=RISCV64_GENERIC - otherwise the build probes -march=native, which
#     a cross compiler rejects ("ISA string must begin with rv32 or rv64").
#  2. HOSTCC=gcc - getarch is COMPILED BY and RUN ON the build machine to
#     detect the host CPU; pointing it at the cross compiler breaks the probe
#     before TARGET is even considered.
#  3. `libs netlib` + NOFORTRAN=1 - build only the C library and skip the
#     `tests` target, whose binaries would have to RUN on riscv64.
# DYNAMIC_ARCH=0 keeps a single portable RV64GC kernel set; NO_LAPACK=1
# because LAPACK ships in its own recipe.
_OB_ARGS="HOSTCC=gcc TARGET=RISCV64_GENERIC DYNAMIC_ARCH=0 NO_SHARED=1 NO_LAPACK=1 NOFORTRAN=1 USE_THREAD=0"
CUSTOM_BUILD="make \$_OB_ARGS libs netlib -j\$HBREW_JOBS"
INSTALL_CMD='make $_OB_ARGS install PREFIX="$stage"'
