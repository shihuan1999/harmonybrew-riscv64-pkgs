NAME="spdlog"
VERSION="1.15.0"
URL="https://github.com/gabime/spdlog/archive/refs/tags/v1.15.0.tar.gz"
SHA256="9962648c9b4f1a7bbc76fd8d9172555bad1871fdb14ff4f842ef87949682caa5"
DESC="Fast C++ logging library (HPC and simulation code)"
HOMEPAGE="https://github.com/gabime/spdlog"
BUILD_METHOD="cmake"
# Built with the bundled fmt (SPDLOG_FMT_EXTERNAL=OFF): the standalone fmt
# package is header/ABI-version sensitive, and spdlog is happier self-contained.
CMAKE_ARGS="-DSPDLOG_BUILD_EXAMPLE=OFF -DSPDLOG_BUILD_TESTS=OFF -DSPDLOG_FMT_EXTERNAL=OFF -DBUILD_SHARED_LIBS=OFF"
