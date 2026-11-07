NAME="units"
VERSION="2.23"
URL="https://ftp.gnu.org/gnu/units/units-2.23.tar.gz"
SHA256="d957b451245925c9e614c4513397449630eaf92bd62b8495ba09bbe351a17370"
DESC="GNU Units: unit conversion calculator"
HOMEPAGE="https://www.gnu.org/software/units/"
BUILD_METHOD="custom"
# units' Makefile expects yacc for the parser; the release tarball ships the
# generated parser, so a plain make works once we pass the prefix through.
CUSTOM_BUILD='make -j"$HBREW_JOBS" units'
INSTALL_CMD='mkdir -p "$stage/bin" "$stage/share/man/man1"
  cp units "$stage/bin/"
  cp units.1 "$stage/share/man/man1/" 2>/dev/null || true'
