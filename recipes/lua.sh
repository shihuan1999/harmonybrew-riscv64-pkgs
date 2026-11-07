NAME="lua"
VERSION="5.4.7"
URL="https://www.lua.org/ftp/lua-5.4.7.tar.gz"
DESC="Lua: lightweight embeddable scripting language"
BUILD_METHOD="custom"
CUSTOM_BUILD='make generic -j"$HBREW_JOBS" MYCFLAGS="-DLUA_USE_POSIX"'
INSTALL_CMD='make install INSTALL_TOP="$stage"'
