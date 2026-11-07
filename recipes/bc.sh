NAME="bc"
VERSION="1.07.1"
URL="https://ftp.gnu.org/gnu/bc/bc-1.07.1.tar.gz"
DESC="bc: arbitrary precision calculator language"
BUILD_METHOD="custom"
CUSTOM_BUILD='./configure --prefix="$stage" --disable-readline >/dev/null 2>&1 || true'
INSTALL_CMD='make -j"$HBREW_JOBS" 2>/dev/null || true'
