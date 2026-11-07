NAME="liquid-dsp"
VERSION="1.7.0"
URL="https://github.com/jgaeddert/liquid-dsp/archive/refs/tags/v1.7.0.tar.gz"
DESC="liquid-dsp: digital signal processing for software-defined radio"
BUILD_METHOD="custom"
CUSTOM_BUILD='./bootstrap.sh >/dev/null 2>&1 || true; ./configure --prefix="$stage" --disable-shared --enable-static'
INSTALL_CMD='make -j"$HBREW_JOBS" && make install'
