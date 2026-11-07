NAME="cuba"
VERSION="4.2.2"
URL="https://github.com/JohannesBuchner/cuba/archive/refs/tags/4.2.2.tar.gz"
DESC="Cuba: multidimensional numerical integration library"
BUILD_METHOD="custom"
CUSTOM_BUILD='./configure --prefix="$stage" --disable-shared >/dev/null 2>&1 || true; make -j"$HBREW_JOBS" libcuba.a'
INSTALL_CMD='make install PREFIX="$stage" 2>/dev/null || { mkdir -p "$stage/lib" "$stage/include"; cp libcuba.a "$stage/lib/"; cp cuba.h "$stage/include/"; }'
