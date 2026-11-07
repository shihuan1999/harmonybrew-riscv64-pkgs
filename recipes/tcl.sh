NAME="tcl"
VERSION="8.6.15"
URL="https://prdownloads.sourceforge.net/tcl/tcl8.6.15-src.tar.gz"
DESC="Tcl: scripting language (many CAE tools embed it)"
BUILD_METHOD="custom"
CUSTOM_BUILD='cd unix && ./configure --prefix="$stage" --disable-shared && make -j"$HBREW_JOBS"'
INSTALL_CMD='cd unix && make install'
