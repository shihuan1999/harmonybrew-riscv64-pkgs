NAME="libmseed"
VERSION="2.19.8"
URL="https://github.com/EarthScope/libmseed/archive/refs/tags/v2.19.8.tar.gz"
DESC="libmseed: miniSEED seismic data format library"
HOMEPAGE="https://github.com/EarthScope/libmseed"
BUILD_METHOD="make"
MAKE_TARGET=""
INSTALL_CMD='mkdir -p "$stage/lib" "$stage/include" "$stage/bin"
  cp libmseed.a "$stage/lib/" 2>/dev/null || true
  cp libmseed.h "$stage/include/" 2>/dev/null || true'
