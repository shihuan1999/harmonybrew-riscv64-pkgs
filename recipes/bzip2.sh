NAME="bzip2"
VERSION="1.0.8"
URL="https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz"
DESC="bzip2: block-sorting file compressor"
BUILD_METHOD="custom"
CUSTOM_BUILD='make -f Makefile-libbz2_so >/dev/null 2>&1 || true; make bzip2 bzip2recover'
INSTALL_CMD='mkdir -p "$stage/bin" "$stage/lib" "$stage/include" && cp bzip2 bzip2recover "$stage/bin/" && cp libbz2.a "$stage/lib/" && cp bzlib.h "$stage/include/"'
