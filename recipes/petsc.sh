NAME="petsc"
VERSION="3.22.2"
URL="https://gitlab.com/petsc/petsc/-/archive/v3.22.2/petsc-v3.22.2.tar.gz"
DESC="PETSc: scalable nonlinear/linear solvers for PDEs (HPC)"
DEPS="openblas"
BUILD_METHOD="custom"
CUSTOM_BUILD='./configure --with-prefix="$stage" --with-blaslapack-lib=-lblas --with-mpi=0 --with-shared-libraries=0 --with-x=0 --with-debugging=0 COPTFLAGS="-O2" FOPTFLAGS="" --download-*=no --with-fc=0'
INSTALL_CMD='make all && make install'
