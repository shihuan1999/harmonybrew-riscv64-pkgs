NAME="lz4"
VERSION="1.10.0"
URL="https://github.com/lz4/lz4/archive/refs/tags/v1.10.0.tar.gz"
DESC="LZ4: extremely fast compression (dataset storage)"
BUILD_METHOD="custom"
CUSTOM_BUILD='make -C lib -j"$HBREW_JOBS" liblz4.a'
INSTALL_CMD='make -C lib install PREFIX="$stage"'
