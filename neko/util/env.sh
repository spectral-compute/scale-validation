# Sourced by the build/test scripts: MPI and dependency paths. Neko is Fortran + MPI: prefer the
# OpenMPI project (built against the toolkit) when it has been built in the same working directory;
# otherwise use the system MPI.
MPI_DIR="$(realpath ../)/openmpi/install"
if [ -e "${MPI_DIR}" ]; then
    export PATH="${MPI_DIR}/bin:${PATH}"
fi
HERE="$(realpath .)"
DEPS="${HERE}/deps"
export PKG_CONFIG_PATH="${HERE}/install/lib/pkgconfig:${DEPS}/lib/pkgconfig:${DEPS}/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="${DEPS}/lib:${DEPS}/lib64:${HERE}/install/lib:${LD_LIBRARY_PATH:-}"
export PATH="${HERE}/install/bin:${PATH}"
