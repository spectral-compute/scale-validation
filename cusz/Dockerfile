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
COPY cusz/ /build/cusz/
COPY test.sh /build/test.sh

# cusz installs to $(pwd)/install relative to workdir = /build/cusz/install.
# Runs the clone/build scripts via the same test.sh driver used below.
# --keep is required here: without it test.sh would rm -rf /build/cusz (its
# own OUT_DIR/TEST_NAME) before globbing scripts from that very directory.
WORKDIR /build
RUN bash test.sh /build /opt/scale "${GPU_ARCH}" cusz --match '-(clone|patch|build)' --keep

# ── test stage ─────────────────────────────────────────────────────────────
# Runs only the test/benchmark scripts (matched by filename, not hardcoded)
# against the project dir the build stage already cloned+built above.
FROM build AS test
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
# The Forgejo Actions runner needs curl inside any container-job image to report
# step completion (https://github.com/nektos/act/issues/107) - without it the test
# stage's own scripts can pass and the job still gets marked failed.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/bin/bash", "-c", "exec bash /build/test.sh /build /opt/scale \"$GPU_ARCH\" cusz --match '-(test|benchmark)' --keep"]

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM ${SCALE_BASE_IMAGE}
USER root
ENV SCALE_LICENSE_ACCEPT=1
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
ENV CUDA_PATH=/opt/scale

# Copy the installed cusz binary and its shared libraries.
COPY --from=build /build/cusz/install /build/cusz/install

ENV PATH="/opt/scale/bin:/build/cusz/install/bin:${PATH}"
# Both SCALE dirs are needed: targets/<arch>/lib has libredscale; lib64 has CUDA API libs.
ENV LD_LIBRARY_PATH="/opt/scale/targets/${GPU_ARCH}/lib:/opt/scale/lib64:/build/cusz/install/lib"

WORKDIR /work

# Usage: `docker run <img> -t f32 -m abs -e 1e-3 -i /work/data.f32 -l 3600x1800 -z`
# to compress, then `-i /work/data.f32.cusza -x --compare /work/data.f32` to
# decompress and check the reconstruction error (mount input data at /work).
ENTRYPOINT ["/bin/bash","-c","source /opt/scale/bin/scaleenv \"$GPU_ARCH\" >/dev/null 2>&1 && exec cusz \"$@\"","--"]
CMD ["--help"]
