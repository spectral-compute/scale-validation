ARG SCALE_BASE_IMAGE=docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.2

FROM ${SCALE_BASE_IMAGE} AS build
USER root
ENV SCALE_LICENSE_ACCEPT=1
SHELL ["/bin/bash", "-c"]
ARG GPU_ARCH=gfx1100

RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# sm_* needs a real CUDA Toolkit to build. Build-stage only -- never reaches the
# publicly-republished runtime stage; no driver installed.
RUN if [[ "${GPU_ARCH}" == sm_* ]]; then \
        wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb && \
        dpkg -i cuda-keyring_1.1-1_all.deb && rm cuda-keyring_1.1-1_all.deb && \
        apt-get update && \
        apt-get install -y --no-install-recommends cuda-toolkit-12-9 && \
        rm -rf /var/lib/apt/lists/*; \
    fi

COPY versions.txt /build/versions.txt
COPY util/ /build/util/
COPY gpujpeg/ /build/gpujpeg/
COPY test.sh /build/test.sh

# Runs the clone/patch/build scripts via the same test.sh driver used below.
# --keep is required here: without it test.sh would rm -rf /build/gpujpeg (its
# own OUT_DIR/TEST_NAME) before globbing scripts from that very directory.
WORKDIR /build
RUN bash test.sh /build /opt/scale "${GPU_ARCH}" gpujpeg --match '-(clone|patch|build)' --keep

# ── test stage ─────────────────────────────────────────────────────────────
# Runs only the test/benchmark scripts (matched by filename, not hardcoded)
# against the project dir the build stage already cloned+built above.
FROM build AS test
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
# 04-test-claims.sh's PSNR check needs python3, and derives interop JPEGs with
# ImageMagick's `convert` (same packages the parity checks in cycles/nvflip need).
# curl is needed by the Forgejo Actions runner itself to report step completion
# (https://github.com/nektos/act/issues/107), not by the test script.
RUN apt-get update && apt-get install -y --no-install-recommends \
    imagemagick \
    python3 \
    curl \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/bin/bash", "-c", "exec bash /build/test.sh /build /opt/scale \"$GPU_ARCH\" gpujpeg --match '-(test|benchmark)' --keep"]

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM ${SCALE_BASE_IMAGE}
USER root
ENV SCALE_LICENSE_ACCEPT=1
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
ENV CUDA_PATH=/opt/scale

# Copy the built CLI tool and shared library (02-build.sh never runs `make
# install`, so both still live directly under build/, not an install/ prefix).
COPY --from=build /build/gpujpeg/build/gpujpegtool /build/gpujpeg/build/gpujpegtool
COPY --from=build /build/gpujpeg/build/libgpujpeg.so* /build/gpujpeg/build/

ENV PATH="/opt/scale/bin:/build/gpujpeg/build:${PATH}"
# Both SCALE dirs are needed: targets/<arch>/lib has libredscale; lib64 has CUDA API libs.
# build/ is appended so gpujpegtool finds libgpujpeg.so, same workaround
# 04-test-claims.sh uses for the same reason (no `make install` was run).
ENV LD_LIBRARY_PATH="/opt/scale/targets/${GPU_ARCH}/lib:/opt/scale/lib64:/build/gpujpeg/build"

WORKDIR /work

# `docker run <img> --encode in.ppm out.jpg` mirrors native gpujpegtool CLI use.
ENTRYPOINT ["/bin/bash","-c","source /opt/scale/bin/scaleenv \"$GPU_ARCH\" >/dev/null 2>&1 && exec gpujpegtool \"$@\"","--"]
CMD ["--help"]
