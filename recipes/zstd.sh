NAME="zstd"
VERSION="1.5.6"
URL="https://github.com/facebook/zstd/archive/refs/tags/v1.5.6.tar.gz"
DESC="Zstandard: fast lossless compression (dataset storage)"
BUILD_METHOD="custom"
CUSTOM_BUILD='make -C lib -j"$HBREW_JOBS" libzstd.a'
INSTALL_CMD='make -C lib install PREFIX="$stage"'
