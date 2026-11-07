NAME="mpfr"
VERSION="4.2.1"
URL="https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz"
SHA256="277807353a6726978996945af13e52829e3abd7a9a5b7fb2793894e18f1fcbb2"
DESC="Multiple-precision floating-point computations with rounding"
HOMEPAGE="https://www.mpfr.org/"
DEPS="gmp"
BUILD_METHOD="autoconf"
# --with-gmp must point at the *staging* prefix of gmp during the build; the
# device-side path is supplied through LDFLAGS/CPPFLAGS by build.sh.
CONFIGURE_ARGS="--disable-shared --enable-static --with-gmp-include=$HBREW_PREFIX/include --with-gmp-lib=$HBREW_PREFIX/lib"
