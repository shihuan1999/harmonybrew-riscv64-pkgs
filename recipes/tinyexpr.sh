NAME="tinyexpr"
VERSION="1.0"
URL="https://github.com/codeplea/tinyexpr/archive/refs/heads/master.tar.gz"
DESC="TinyExpr: tiny recursive descent expression parser/evaluator"
HOMEPAGE="https://github.com/codeplea/tinyexpr"
BUILD_METHOD="make"
MAKE_TARGET=""
INSTALL_CMD='mkdir -p "$stage/lib" "$stage/include"
  gcc -c -O2 -fPIC tinyexpr.c -o tinyexpr.o && ar rcs "$stage/lib/libtinyexpr.a" tinyexpr.o
  cp tinyexpr.h "$stage/include/"'
