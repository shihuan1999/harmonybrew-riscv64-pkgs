NAME="parallel"
VERSION="20241022"
URL="https://ftp.gnu.org/gnu/parallel/parallel-20241022.tar.bz2"
DESC="GNU Parallel: shell tool for parallel job execution (parameter sweeps)"
BUILD_METHOD="custom"
CUSTOM_BUILD='true'
INSTALL_CMD='./configure --prefix="$stage" && make install'
