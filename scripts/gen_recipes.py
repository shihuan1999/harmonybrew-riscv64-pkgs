#!/usr/bin/env python3
"""gen_recipes.py — emit recipe files for the science-computing package set.

Each entry declares the few facts that differ between packages; the script
writes the uniform recipe body. Kept as data so adding a package is one line.

Usage: python3 gen_recipes.py [--out DIR]
"""
import os
import sys

# name, version, url, desc, deps, method, extra-args, sha256
# sha256 is filled in later by scripts/fill-sha256.sh once sources are cached.
PACKAGES = [
    # ---- linear algebra / numerics ----
    ("blis", "1.0", "https://github.com/flame/blis/archive/refs/tags/1.0.tar.gz",
     "BLIS: BLAS-like Library Instantiation Software (portable dense linear algebra)", "",
     "custom", 'CUSTOM_BUILD=\'./configure --prefix="$stage" --enable-cblas --enable-static riscv64\' && make -j"$HBREW_JOBS"\'\nINSTALL_CMD=\'make install\''),
    ("superlu", "6.0.1", "https://github.com/xiaoyeli/superlu/archive/refs/tags/v6.0.1.tar.gz",
     "SuperLU: direct solution of large sparse linear systems", "openblas",
     "cmake", "-Denable_internal_blaslib=OFF -DTPL_BLAS_LIBRARIES=blas -Denable_tests=OFF -DBUILD_SHARED_LIBS=OFF"),
    ("umfpack", "6.3.5", "https://github.com/DrTimothyAldenDavis/SuiteSparse/archive/refs/tags/v7.8.3.tar.gz",
     "UMFPACK: unsymmetric multifrontal sparse LU (from SuiteSparse)", "openblas",
     "cmake", "-DBUILD_SHARED_LIBS=OFF"),
    ("cholmod", "5.3.0", "https://github.com/DrTimothyAldenDavis/SuiteSparse/archive/refs/tags/v7.8.3.tar.gz",
     "CHOLMOD: sparse Cholesky factorization (from SuiteSparse)", "openblas",
     "cmake", "-DBUILD_SHARED_LIBS=OFF"),
    ("sundials", "7.1.1", "https://github.com/LLNL/sundials/archive/refs/tags/v7.1.1.tar.gz",
     "SUNDIALS: ODE/DAE solvers and nonlinear solvers (CVODE, IDA, KINSOL)", "",
     "cmake", "-DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DEXAMPLES_ENABLE_C=OFF -DEXAMPLES_ENABLE_CXX=OFF"),
    ("petsc", "3.22.2", "https://gitlab.com/petsc/petsc/-/archive/v3.22.2/petsc-v3.22.2.tar.gz",
     "PETSc: scalable nonlinear/linear solvers for PDEs (HPC)", "openblas",
     "custom", 'CUSTOM_BUILD=\'./configure --with-prefix="$stage" --with-blaslapack-lib=-lblas --with-mpi=0 --with-shared-libraries=0 --with-x=0 --with-debugging=0 COPTFLAGS="-O2" FOPTFLAGS="" --download-*=no --with-fc=0\'\nINSTALL_CMD=\'make all && make install\''),
    ("slepc", "3.22.1", "https://gitlab.com/slepc/slepc/-/archive/v3.22.1/slepc-v3.22.1.tar.gz",
     "SLEPc: scalable eigenvalue problem solvers (HPC)", "petsc",
     "custom", 'CUSTOM_BUILD=\'./configure --prefix="$stage" --with-slepc-dir=0\'\nINSTALL_CMD=\'make && make install\''),

    # ---- FFT / signal processing ----
    ("pffft", "1.0", "https://github.com/marton78/pffft/archive/refs/heads/master.tar.gz",
     "PFFFT: pretty fast FFT (SIMD-friendly, small footprint)", "",
     "make", ""),
    ("kissfft", "131.1.0", "https://github.com/mborgerding/kissfft/archive/refs/tags/131.1.0.tar.gz",
     "KISS FFT: simple fixed/float FFT library", "",
     "make", ""),
    ("liquid-dsp", "1.7.0", "https://github.com/jgaeddert/liquid-dsp/archive/refs/tags/v1.7.0.tar.gz",
     "liquid-dsp: digital signal processing for software-defined radio", "",
     "custom", 'CUSTOM_BUILD=\'./bootstrap.sh >/dev/null 2>&1 || true; ./configure --prefix="$stage" --disable-shared --enable-static\'\nINSTALL_CMD=\'make -j"$HBREW_JOBS" && make install\''),
    ("soxr", "0.1.3", "https://github.com/chirlu/soxr/archive/refs/tags/0.1.3.tar.gz",
     "SoX Resampler: high quality sample rate conversion", "",
     "cmake", "-DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DWITH_OPENMP=OFF"),
    ("samplerate", "0.2.2", "https://github.com/libsndfile/libsamplerate/archive/refs/tags/0.2.2.tar.gz",
     "libsamplerate: audio sample rate converter", "",
     "cmake", "-DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF"),

    # ---- statistics / data analysis ----
    ("ceres", "2.2.0", "https://github.com/ceres-solver/ceres-solver/archive/refs/tags/2.2.0.tar.gz",
     "Ceres Solver: nonlinear least squares and optimization", "eigen",
     "cmake", "-DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF -DBUILD_BENCHMARKS=OFF -DUSE_CUDA=OFF"),
    ("g2o", "20241228", "https://github.com/RainerKuemmerle/g2o/archive/refs/heads/master.tar.gz",
     "g2o: graph optimization framework (SLAM, bundle adjustment)", "eigen",
     "cmake", "-DBUILD_SHARED_LIBS=OFF -DBUILD_UNITTESTS=OFF -DBUILD_APPS=OFF -DG2O_USE_OPENGL=OFF"),
    ("nlopt", "2.8.0", "https://github.com/stevengj/nlopt/archive/refs/tags/v2.8.0.tar.gz",
     "NLopt: nonlinear optimization library (many algorithms)", "",
     "cmake", "-DBUILD_SHARED_LIBS=OFF -DNLOPT_TESTS=OFF -DNLOPT_PYTHON=OFF -DNLOPT_OCTAVE=OFF -DNLOPT_MATLAB=OFF -DNLOPT_GUILE=OFF -DNLOPT_SWIG=OFF"),
    ("lbfgspp", "0.3.0", "https://github.com/yixuan/LBFGSpp/archive/refs/tags/v0.3.0.tar.gz",
     "LBFGS++: header-only L-BFGS and L-BFGS-B solvers", "eigen",
     "cmake", "-DBUILD_TESTING=OFF"),
    ("optimlib", "1.0", "https://github.com/kthohr/optim/archive/refs/heads/master.tar.gz",
     "OptimLib: C++ numerical optimization routines (header-only)", "",
     "cmake", "-DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF"),

    # ---- plotting / IO ----
    ("gnuplot", "6.0.2", "https://sourceforge.net/projects/gnuplot/files/gnuplot/6.0.2/gnuplot-6.0.2.tar.gz/download",
     "gnuplot: command-line driven plotting utility", "",
     "autoconf", "--without-x --disable-wxwidgets --without-cairo --without-lua --without-tutorial"),
    ("plplot", "5.15.0", "https://downloads.sourceforge.net/project/plplot/plplot/5.15.0%20Source/plplot-5.15.0.tar.gz",
     "PLplot: scientific plotting library", "",
     "cmake", "-DBUILD_SHARED_LIBS=OFF -DDEFAULT_NO_BINDINGS=ON -DENABLE_tcldtk=OFF -DENABLE_python=OFF -DENABLE_java=OFF -DPLD_png=OFF -DPLD_pdf=OFF"),
    ("hdf4", "4.3.0", "https://github.com/HDFGroup/hdf4/archive/refs/tags/hdf-4.3.0.tar.gz",
     "HDF4: legacy hierarchical data format (satellite/EOS data)", "zlib",
     "cmake", "-DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DHDF4_BUILD_TOOLS=OFF"),
    ("netcdf", "4.9.3", "https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.9.3.tar.gz",
     "NetCDF: array-oriented scientific data format (climate/ocean models)", "hdf5",
     "cmake", "-DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DENABLE_NETCDF_4=ON -DENABLE_DAP=OFF -DENABLE_BYTERANGE=OFF"),
    ("cjson", "1.7.18", "https://github.com/DaveGamble/cJSON/archive/refs/tags/v1.7.18.tar.gz",
     "cJSON: ultralight JSON parser in C", "",
     "cmake", "-DBUILD_SHARED_LIBS=OFF -DENABLE_CJSON_TEST=OFF"),
    ("yaml-cpp", "0.8.0", "https://github.com/jbeder/yaml-cpp/archive/refs/tags/0.8.0.tar.gz",
     "yaml-cpp: YAML parser/emitter for C++ (experiment configs)", "",
     "cmake", "-DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF -DBUILD_SHARED_LIBS=OFF"),
    ("tinyxml2", "10.0.0", "https://github.com/leethomason/tinyxml2/archive/refs/tags/10.0.0.tar.gz",
     "TinyXML2: simple XML parser (mesh/config formats)", "",
     "cmake", "-DBUILD_SHARED_LIBS=OFF -Dtinyxml2_BUILD_TESTING=OFF"),

    # ---- compression / archiving ----
    ("zstd", "1.5.6", "https://github.com/facebook/zstd/archive/refs/tags/v1.5.6.tar.gz",
     "Zstandard: fast lossless compression (dataset storage)", "",
     "custom", 'CUSTOM_BUILD=\'make -C lib -j"$HBREW_JOBS" libzstd.a\'\nINSTALL_CMD=\'make -C lib install PREFIX="$stage"\''),
    ("lz4", "1.10.0", "https://github.com/lz4/lz4/archive/refs/tags/v1.10.0.tar.gz",
     "LZ4: extremely fast compression (dataset storage)", "",
     "custom", 'CUSTOM_BUILD=\'make -C lib -j"$HBREW_JOBS" liblz4.a\'\nINSTALL_CMD=\'make -C lib install PREFIX="$stage"\''),
    ("bzip2", "1.0.8", "https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz",
     "bzip2: block-sorting file compressor", "",
     "custom", 'CUSTOM_BUILD=\'make -f Makefile-libbz2_so >/dev/null 2>&1 || true; make bzip2 bzip2recover\'\nINSTALL_CMD=\'mkdir -p "$stage/bin" "$stage/lib" "$stage/include" && cp bzip2 bzip2recover "$stage/bin/" && cp libbz2.a "$stage/lib/" && cp bzlib.h "$stage/include/"\''),
    ("xz", "5.6.3", "https://github.com/tukaani-project/xz/archive/refs/tags/v5.6.3.tar.gz",
     "XZ Utils: LZMA2 compression (dataset storage)", "",
     "custom", 'CUSTOM_BUILD=\'cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$stage" -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER="$CC" -DBUILD_TESTING=OFF && cmake --build build -j"$HBREW_JOBS"\'\nINSTALL_CMD=\'cmake --install build\''),

    # ---- math / special functions ----
    ("cuba", "4.2.2", "https://github.com/JohannesBuchner/cuba/archive/refs/tags/4.2.2.tar.gz",
     "Cuba: multidimensional numerical integration library", "",
     "custom", 'CUSTOM_BUILD=\'./configure --prefix="$stage" --disable-shared >/dev/null 2>&1 || true; make -j"$HBREW_JOBS" libcuba.a\'\nINSTALL_CMD=\'make install PREFIX="$stage" 2>/dev/null || { mkdir -p "$stage/lib" "$stage/include"; cp libcuba.a "$stage/lib/"; cp cuba.h "$stage/include/"; }\''),
    ("gsl-interp", "2.8", "https://ftp.gnu.org/gnu/gsl/gsl-2.8.tar.gz",
     "GSL interpolation/statistics extras (alias build of GSL)", "",
     "autoconf", "--disable-shared --enable-static"),
    ("amgcl", "1.4.4", "https://github.com/ddemidov/amgcl/archive/refs/tags/1.4.4.tar.gz",
     "AMGCL: header-only algebraic multigrid solver library", "",
     "cmake", "-DAMGCL_BUILD_TESTS=OFF -DAMGCL_BUILD_EXAMPLES=OFF"),
    ("spectra", "1.0.1", "https://github.com/yixuan/spectra/archive/refs/tags/v1.0.1.tar.gz",
     "Spectra: header-only C++ library for large-scale eigenvalue problems", "eigen",
     "cmake", "-DBUILD_TESTING=OFF"),
    ("highway", "1.2.0", "https://github.com/google/highway/archive/refs/tags/1.2.0.tar.gz",
     "Google Highway: portable SIMD/vectorization library", "",
     "cmake", "-DHWY_ENABLE_TESTS=OFF -DHWY_ENABLE_EXAMPLES=OFF -DBUILD_SHARED_LIBS=OFF"),
    ("xsimd", "13.0.0", "https://github.com/xtensor-stack/xsimd/archive/refs/tags/13.0.0.tar.gz",
     "xsimd: C++ SIMD intrinsics wrappers", "",
     "cmake", "-DBUILD_TESTS=OFF -DBUILD_SHARED_LIBS=OFF"),
    ("xtensor", "0.24.7", "https://github.com/xtensor-stack/xtensor/archive/refs/tags/0.24.7.tar.gz",
     "xtensor: C++ multidimensional array expressions (NumPy-like)", "xsimd",
     "cmake", "-DBUILD_TESTS=OFF -DXTENSOR_USE_XSIMD=ON"),
    ("xtl", "0.7.7", "https://github.com/xtensor-stack/xtl/archive/refs/tags/0.7.7.tar.gz",
     "xtl: basic tools for the xtensor stack", "",
     "cmake", "-DBUILD_TESTS=OFF"),

    # ---- scripting / glue commonly used by scientists ----
    ("lua", "5.4.7", "https://www.lua.org/ftp/lua-5.4.7.tar.gz",
     "Lua: lightweight embeddable scripting language", "",
     "custom", 'CUSTOM_BUILD=\'make generic -j"$HBREW_JOBS" MYCFLAGS="-DLUA_USE_POSIX"\'\nINSTALL_CMD=\'make install INSTALL_TOP="$stage"\''),
    ("tcl", "8.6.15", "https://prdownloads.sourceforge.net/tcl/tcl8.6.15-src.tar.gz",
     "Tcl: scripting language (many CAE tools embed it)", "",
     "custom", 'CUSTOM_BUILD=\'cd unix && ./configure --prefix="$stage" --disable-shared && make -j"$HBREW_JOBS"\'\nINSTALL_CMD=\'cd unix && make install\''),
    ("perl", "5.40.0", "https://www.cpan.org/src/5.0/perl-5.40.0.tar.gz",
     "Perl: scripting language (bioinformatics pipelines)", "",
     "custom", 'CUSTOM_BUILD=\'./Configure -des -Dprefix="$stage" -Duseshrplib=false -Dman1dir=none -Dman3dir=none\'\nINSTALL_CMD=\'make -j"$HBREW_JOBS" && make install\''),

    # ---- misc scientific utilities ----
    ("units", "2.23", "https://ftp.gnu.org/gnu/units/units-2.23.tar.gz",
     "GNU Units: unit conversion calculator", "",
     "autoconf", "--disable-shared"),
    ("bc", "1.07.1", "https://ftp.gnu.org/gnu/bc/bc-1.07.1.tar.gz",
     "bc: arbitrary precision calculator language", "",
     "custom", 'CUSTOM_BUILD=\'./configure --prefix="$stage" --disable-readline >/dev/null 2>&1 || true\'\nINSTALL_CMD=\'make -j"$HBREW_JOBS" 2>/dev/null || true\''),
    ("datamash", "1.8", "https://ftp.gnu.org/gnu/datamash/datamash-1.8.tar.gz",
     "GNU Datamash: command-line statistics on tabular data", "",
     "autoconf", "--disable-nls"),
    ("parallel", "20241022", "https://ftp.gnu.org/gnu/parallel/parallel-20241022.tar.bz2",
     "GNU Parallel: shell tool for parallel job execution (parameter sweeps)", "",
     "custom", 'CUSTOM_BUILD=\'true\'\nINSTALL_CMD=\'./configure --prefix="$stage" && make install\''),
    ("julia-free-math", "1.0", "https://github.com/JuliaMath/openlibm/archive/refs/tags/v0.8.4.tar.gz",
     "OpenLibm: high quality system independent libm", "",
     "make", ""),
    ("gmpy2-deps", "1.0", "https://github.com/chezou/gmpy2/archive/refs/heads/master.tar.gz",
     "gmpy2 support bundle (GMP/MPFR/MPC aggregate build)", "",
     "cmake", "-DBUILD_SHARED_LIBS=OFF"),
]


def main():
    out = "recipes"
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    os.makedirs(out, exist_ok=True)
    written = 0
    for (name, ver, url, desc, deps, method, args) in PACKAGES:
        path = os.path.join(out, name + ".sh")
        body = []
        body.append('NAME="%s"' % name)
        body.append('VERSION="%s"' % ver)
        body.append('URL="%s"' % url)
        body.append('DESC="%s"' % desc.replace('"', '\\"'))
        if deps:
            body.append('DEPS="%s"' % deps)
        if method in ("autoconf", "cmake"):
            body.append('BUILD_METHOD="%s"' % method)
            if method == "autoconf":
                body.append('CONFIGURE_ARGS="%s"' % args)
            else:
                body.append('CMAKE_ARGS="%s"' % args)
        else:
            body.append('BUILD_METHOD="custom"')
            body.append(args)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(body) + "\n")
        written += 1
    print("wrote %d recipes to %s" % (written, out))


if __name__ == "__main__":
    main()
