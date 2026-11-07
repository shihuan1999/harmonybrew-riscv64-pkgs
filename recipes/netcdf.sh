NAME="netcdf"
VERSION="4.9.3"
URL="https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.9.3.tar.gz"
SHA256="990f46d49525d6ab5dc4249f8684c6deeaf54de6fec63a187e9fb382cc0ffdff"
DESC="NetCDF: array-oriented scientific data format (climate/ocean models)"
HOMEPAGE="https://www.unidata.ucar.edu/software/netcdf/"
BUILD_METHOD="cmake"
# No HDF5 dependency: this build is netCDF-3 (classic) + C library only, which
# is what most numeric codes need and avoids the HDF5 plugin/ABI chain.
CMAKE_ARGS="-DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DENABLE_NETCDF_4=OFF -DENABLE_DAP=OFF -DENABLE_BYTERANGE=OFF -DENABLE_HDF5=OFF -DUSE_HDF5=OFF -DENABLE_NCZARR=OFF -DENABLE_V2_API=ON"
