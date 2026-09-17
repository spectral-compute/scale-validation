#!/usr/bin/env bash
#
# Build the mesh format libraries 00-clone.sh fetched -- HDF5, MED and CGNS --
# into one shared prefix that 03-build.sh points code_saturne's configure at.
#
# They are pure host-side I/O libraries: nothing here is compiled by SCALE, and
# none of it is under test. They exist so the preprocessor can read the .med
# and .cgns meshes the tutorials ship (see 07-test-mixing-tee.sh).
#
# Order matters: MED and CGNS both link HDF5, so HDF5 installs first and the
# other two are pointed at the same prefix.
. "$(dirname "$0")"/../util/prelude.sh
. "$(dirname "$0")"/common.bash

# CMake 4 refuses projects declaring a minimum below 3.5, which both HDF5
# 1.12.3 and CGNS 4.4.0 still do in places.
cmake_compat=(-DCMAKE_POLICY_VERSION_MINIMUM=3.5)

# HDF5. Built with CMake rather than autotools: the git checkout has no
# generated configure and autogen.sh wants specific autotools versions.
# The C library is what MED and CGNS link, plus the high-level API MED uses.
# The command line tools are built only because MED's configure refuses to
# proceed without an h5dump (its own test suite dumps files with it); no C++,
# Fortran or tests.
hdf5_args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="${DEPS_INSTALL}"
    -DBUILD_SHARED_LIBS=ON
    -DBUILD_STATIC_LIBS=OFF
    -DBUILD_TESTING=OFF
    -DHDF5_BUILD_EXAMPLES=OFF
    -DHDF5_BUILD_TOOLS=ON
    -DHDF5_BUILD_UTILS=OFF
    -DHDF5_BUILD_CPP_LIB=OFF
    -DHDF5_BUILD_FORTRAN=OFF
    -DHDF5_BUILD_HL_LIB=ON
)
rm -rf hdf5/build
cmake -S hdf5 -B hdf5/build "${cmake_compat[@]}" "${hdf5_args[@]}"
cmake --build hdf5/build -j"$(nproc)"
cmake --install hdf5/build

# MED. Autotools, from the tarball, so configure is already generated.
# --with-med_int=long, no Fortran and no Python: the options code_saturne's own
# installer uses, and all code_saturne reads is the C API.
#
# CMake names the tools of a shared-only HDF5 build h5dump-shared, which MED's
# AC_PATH_PROG never looks for; presetting H5DUMP skips that search.
med_args=(
    --prefix="${DEPS_INSTALL}"
    --with-hdf5="${DEPS_INSTALL}"
    --with-hdf5bin="${DEPS_INSTALL}/bin"
    --with-med_int=long
    --disable-fortran
    --disable-python
    --disable-static
)
rm -rf med/build
mkdir -p med/build
(cd med/build && H5DUMP="${DEPS_INSTALL}/bin/h5dump-shared" ../configure "${med_args[@]}")
make -C med/build -j"$(nproc)"
make -C med/build install

# CGNS. 64-bit ids and scoped enums are what code_saturne's installer asks for;
# HDF5 support is the point of building it here at all.
cgns_args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="${DEPS_INSTALL}"
    -DCGNS_ENABLE_64BIT=ON
    -DCGNS_ENABLE_SCOPING=ON
    -DCGNS_ENABLE_HDF5=ON
    -DCGNS_BUILD_SHARED=ON
    -DCGNS_USE_SHARED=ON
    -DHDF5_ROOT="${DEPS_INSTALL}"
)
rm -rf cgns/build
cmake -S cgns -B cgns/build "${cmake_compat[@]}" "${cgns_args[@]}"
cmake --build cgns/build -j"$(nproc)"
cmake --install cgns/build
