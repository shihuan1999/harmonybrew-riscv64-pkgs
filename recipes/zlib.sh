NAME="zlib"
VERSION="1.3.1"
URL="https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz"
SHA256="9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23"
DESC="zlib compression library (dependency of many scientific tools)"
HOMEPAGE="https://zlib.net/"
BUILD_METHOD="custom"
# zlib's configure is a hand-written script: it rejects --host and instead
# reads CHOST. CHOST must still be set so it picks the cross toolchain naming
# for the AR/RANLIB it calls.
CUSTOM_BUILD='CHOST=$HOST ./configure --prefix="$stage" --static && make -j"$HBREW_JOBS"'
INSTALL_CMD='make install'
