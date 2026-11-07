NAME="xz"
VERSION="5.6.3"
URL="https://github.com/tukaani-project/xz/archive/refs/tags/v5.6.3.tar.gz"
DESC="XZ Utils: LZMA2 compression (dataset storage)"
BUILD_METHOD="custom"
CUSTOM_BUILD='cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$stage" -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER="$CC" -DBUILD_TESTING=OFF && cmake --build build -j"$HBREW_JOBS"'
INSTALL_CMD='cmake --install build'
