NAME="slepc"
VERSION="3.22.1"
URL="https://gitlab.com/slepc/slepc/-/archive/v3.22.1/slepc-v3.22.1.tar.gz"
DESC="SLEPc: scalable eigenvalue problem solvers (HPC)"
DEPS="petsc"
BUILD_METHOD="custom"
CUSTOM_BUILD='./configure --prefix="$stage" --with-slepc-dir=0'
INSTALL_CMD='make && make install'
