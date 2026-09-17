#!/bin/bash
#
# Build the mesh format libraries 00-clone.sh fetched -- HDF5, MED and CGNS --
# into one shared prefix that 03-build.sh points code_saturne's configure at.
#
# They are pure host-side I/O libraries: nothing here is compiled by SCALE, and
# none of it is under test. They exist so the preprocessor can read the .med
# and .cgns meshes the tutorials ship (see 07-example.sh).
#
# Order matters: MED and CGNS both link HDF5, so HDF5 installs first and the
# other two are pointed at the same prefix.
#
# Independent of 01-patch.sh; it only has to run before 03-build.sh, whose
# configure looks for the three in this prefix.

set -ETeuo pipefail

deps_install_dir="$(realpath -m deps-install)"

# CMake 4 refuses projects declaring a minimum below 3.5, which both HDF5
# 1.12.3 and CGNS 4.4.0 still do in places.
cmake_compat="-DCMAKE_POLICY_VERSION_MINIMUM=3.5"

# HDF5. Built with CMake rather than autotools: the git checkout has no
# generated configure and autogen.sh wants specific autotools versions.
# The C library is what MED and CGNS link, plus the high-level API MED uses.
# The command line tools are built only because MED's configure refuses to
# proceed without an h5dump (its own test suite dumps files with it); no C++,
# Fortran or tests.
rm -rf hdf5/build
cmake -S hdf5 -B hdf5/build ${cmake_compat} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${deps_install_dir}" \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_STATIC_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -DHDF5_BUILD_EXAMPLES=OFF \
    -DHDF5_BUILD_TOOLS=ON \
    -DHDF5_BUILD_UTILS=OFF \
    -DHDF5_BUILD_CPP_LIB=OFF \
    -DHDF5_BUILD_FORTRAN=OFF \
    -DHDF5_BUILD_HL_LIB=ON
cmake --build hdf5/build -j"$(nproc)"
cmake --install hdf5/build

# MED. Autotools, from the tarball, so configure is already generated.
# --with-med_int=long, no Fortran and no Python: the options code_saturne's own
# installer uses, and all code_saturne reads is the C API.
rm -rf med/build
mkdir -p med/build
# CMake names the tools of a shared-only HDF5 build h5dump-shared, which
# MED's AC_PATH_PROG never looks for; presetting H5DUMP skips that search.
(cd med/build && H5DUMP="${deps_install_dir}/bin/h5dump-shared" ../configure \
    --prefix="${deps_install_dir}" \
    --with-hdf5="${deps_install_dir}" \
    --with-hdf5bin="${deps_install_dir}/bin" \
    --with-med_int=long \
    --disable-fortran \
    --disable-python \
    --disable-static)
make -C med/build -j"$(nproc)"
make -C med/build install

# CGNS. 64-bit ids and scoped enums are what code_saturne's installer asks for;
# HDF5 support is the point of building it here at all.
rm -rf cgns/build
cmake -S cgns -B cgns/build ${cmake_compat} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${deps_install_dir}" \
    -DCGNS_ENABLE_64BIT=ON \
    -DCGNS_ENABLE_SCOPING=ON \
    -DCGNS_ENABLE_HDF5=ON \
    -DCGNS_BUILD_SHARED=ON \
    -DCGNS_USE_SHARED=ON \
    -DHDF5_ROOT="${deps_install_dir}"
cmake --build cgns/build -j"$(nproc)"
cmake --install cgns/build
