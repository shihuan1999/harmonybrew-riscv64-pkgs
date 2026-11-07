NAME="blis"
VERSION="1.0"
URL="https://github.com/flame/blis/archive/refs/tags/1.0.tar.gz"
DESC="BLIS: BLAS-like Library Instantiation Software (portable dense linear algebra)"
BUILD_METHOD="custom"
CUSTOM_BUILD='./configure --prefix="$stage" --enable-cblas --enable-static riscv64' && make -j"$HBREW_JOBS"'
INSTALL_CMD='make install'
