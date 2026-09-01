ARG SCALE_BASE_IMAGE=docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.2

FROM ${SCALE_BASE_IMAGE} AS build
USER root
ENV SCALE_LICENSE_ACCEPT=1
SHELL ["/bin/bash", "-c"]
ARG GPU_ARCH=gfx1100

# FastEddy links against NetCDF for its I/O layer (-lnetcdf, see
# FastEddy/SRC/FEMAIN/Makefile). libnetcdf-dev pulls in the matching runtime lib
# transitively; that runtime lib is installed again explicitly in the runtime stage
# below since it's not copied out of this stage. lbzip2 is needed by `tar -xf` to
# extract openmpi's .tar.bz2 release tarball in openmpi/00-clone.sh.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnetcdf-dev \
    lbzip2 \
    && rm -rf /var/lib/apt/lists/*

# sm_* needs a real CUDA Toolkit to build. Both openmpi (configured --with-cuda, see
# openmpi/01-configure.sh) and FastEddy itself (nvcc-compiled CUDA kernels) need it.
# Build-stage only -- never reaches the publicly-republished runtime stage; no driver
# installed.
RUN if [[ "${GPU_ARCH}" == sm_* ]]; then \
        wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb && \
        dpkg -i cuda-keyring_1.1-1_all.deb && rm cuda-keyring_1.1-1_all.deb && \
        apt-get update && \
        apt-get install -y --no-install-recommends cuda-toolkit-12-9 && \
        rm -rf /var/lib/apt/lists/*; \
    fi

COPY versions.txt /build/versions.txt
COPY util/ /build/util/
COPY openmpi/ /build/openmpi/
COPY fasteddy/ /build/fasteddy/
COPY test.sh /build/test.sh

WORKDIR /build

# openmpi is a build-only dependency (.build-only, .skip-ci -- never scheduled as its
# own CI matrix entry) that fasteddy/01-build.sh refuses to build without: it checks
# for ${OUT_DIR}/openmpi/install (a sibling of fasteddy's own workdir, i.e.
# /build/openmpi/install) and exports PATH/LD_LIBRARY_PATH to it. Build it first, into
# the same shared /build workdir, via the same test.sh driver every other project
# uses. All three of openmpi's scripts (00-clone, 01-configure, 02-build) are
# setup/build steps -- there's no test/benchmark script to exclude, so --match is
# omitted entirely, which runs every *.sh (see "Running a test" in CLAUDE.md).
# --keep is required: without it test.sh would rm -rf /build/openmpi (its own
# OUT_DIR/TEST_NAME) before globbing scripts from that very directory -- the same
# reason caffe's Dockerfile needs it for caffe's own directory.
RUN bash test.sh /build /opt/scale "${GPU_ARCH}" openmpi --keep

# Now build FastEddy itself against the openmpi install produced above.
# --match excludes 02-benchmark-example.sh (the renamed benchmark/comparison script --
# see fasteddy/02-benchmark-example.sh -- run only in the test stage below); FastEddy
# has no patch step, so only clone/build remain. Same --keep requirement as above.
RUN bash test.sh /build /opt/scale "${GPU_ARCH}" fasteddy --match '-(clone|build)' --keep

# ── test stage ─────────────────────────────────────────────────────────────
# Runs only the test/benchmark scripts (matched by filename, not hardcoded)
# against the project dir the build stage already cloned+built above.
FROM build AS test
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
# 02-benchmark-example.sh runs a real simulation via mpirun, renders plots from a
# Jupyter notebook (tutorials/notebooks/MAKE_FE_TUTORIAL_PLOTS.ipynb upstream, which
# itself imports numpy/pandas/xarray/netCDF4/scipy/matplotlib), then compares each
# plot's MSE against the bundled ref-1/ref-4 reference images via ImageMagick's
# `compare` and python3, exiting 1 if any comparison exceeds its threshold. None of
# this is needed by the runtime stage, so it's added here only, same as
# nvflip/cycles add their own test-only imagemagick/python3. curl is needed by
# the Forgejo Actions runner itself to report step completion
# (https://github.com/nektos/act/issues/107), not by the test script.
RUN apt-get update && apt-get install -y --no-install-recommends \
    imagemagick \
    python3 \
    python3-numpy \
    python3-pandas \
    python3-scipy \
    python3-matplotlib \
    python3-netcdf4 \
    python3-xarray \
    jupyter-core \
    python3-nbclient \
    python3-nbformat \
    python3-ipykernel \
    curl \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/bin/bash", "-c", "exec bash /build/test.sh /build /opt/scale \"$GPU_ARCH\" fasteddy --match '-(test|benchmark)' --keep"]

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM ${SCALE_BASE_IMAGE}
USER root
ENV SCALE_LICENSE_ACCEPT=1
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
ENV CUDA_PATH=/opt/scale

# NetCDF runtime lib the FastEddy binary links against for its I/O layer.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnetcdf19t64 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built FastEddy binary and the bundled OpenMPI install it needs at runtime
# (mpirun + libmpi/libopen-pal/etc are not part of the SCALE base image).
COPY --from=build /build/openmpi/install /build/openmpi/install
COPY --from=build /build/fasteddy/fasteddy/SRC/FEMAIN/FastEddy /build/fasteddy/fasteddy/SRC/FEMAIN/FastEddy

ENV PATH="/opt/scale/bin:/build/openmpi/install/bin:/build/fasteddy/fasteddy/SRC/FEMAIN:${PATH}"
# Both SCALE dirs are needed: targets/<arch>/lib has libredscale; lib64 has CUDA API
# libs. openmpi/install/lib has libmpi and friends.
ENV LD_LIBRARY_PATH="/opt/scale/targets/${GPU_ARCH}/lib:/opt/scale/lib64:/build/openmpi/install/lib"

WORKDIR /work

# FastEddy takes exactly one argument, a .in parameter file (see
# SRC/FEMAIN/FastEddy.c: argc != 2 prints "usage: FastEddy paramFile" and exits 0),
# so that's what CMD's absence naturally produces here -- no fake --help flag (passing
# "--help" as argv[1] would make FastEddy try to open a file literally named
# "--help"). A real run needs a FastEddy .in config mounted at /work (see README);
# override the process count with `-e NP=<n>`.
# Usage: `docker run <img> /work/YourCase.in` mirrors 02-benchmark-example.sh's own
# `mpirun -np <N> .../FastEddy <config>.in`.
ENV NP=1
ENTRYPOINT ["/bin/bash","-c","source /opt/scale/bin/scaleenv \"$GPU_ARCH\" >/dev/null 2>&1 && exec mpirun -np \"$NP\" FastEddy \"$@\"","--"]
CMD []
