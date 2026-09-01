ARG SCALE_BASE_IMAGE=docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.2

FROM ${SCALE_BASE_IMAGE} AS build
USER root
ENV SCALE_LICENSE_ACCEPT=1
SHELL ["/bin/bash", "-c"]
ARG GPU_ARCH=gfx1100

# 00-clone.sh's download-input.sh needs curl to fetch RabbitInput.tgz (~2.9 GB).
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
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
COPY rabbitct/ /build/rabbitct/
COPY test.sh /build/test.sh

# 00-clone.sh downloads the ~2.9 GB RabbitInput dataset (RabbitInput.rct plus
# reference volumes) and 01-build.sh compiles the LolaCUDA algorithm variant.
# --keep is required here: without it test.sh would rm -rf /build/rabbitct (its
# own OUT_DIR/TEST_NAME) before globbing scripts from that very directory.
WORKDIR /build
RUN bash test.sh /build /opt/scale "${GPU_ARCH}" rabbitct --match '-(clone|patch|build)' --keep

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
ENTRYPOINT ["/bin/bash", "-c", "exec bash /build/test.sh /build /opt/scale \"$GPU_ARCH\" rabbitct --match '-(test|benchmark)' --keep"]

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM ${SCALE_BASE_IMAGE}
USER root
ENV SCALE_LICENSE_ACCEPT=1
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
ENV CUDA_PATH=/opt/scale

# Copy the built binary and the bundled reference dataset from the nested clone
# (00-clone.sh clones into rabbitct/rabbitct relative to the build-stage
# WORKDIR, and downloads RabbitInput/ into that same directory).
COPY --from=build /build/rabbitct/rabbitct/rabbitRunner-NVCC /build/rabbitct/rabbitct/rabbitRunner-NVCC
COPY --from=build /build/rabbitct/rabbitct/RabbitInput /build/rabbitct/rabbitct/RabbitInput

ENV PATH="/opt/scale/bin:/build/rabbitct/rabbitct:${PATH}"
# Both SCALE dirs are needed: targets/<arch>/lib has libredscale; lib64 has CUDA API libs.
ENV LD_LIBRARY_PATH="/opt/scale/targets/${GPU_ARCH}/lib:/opt/scale/lib64"

WORKDIR /work

# Reconstructs the bundled sample dataset at 1024^3 with LolaCUDA and verifies the
# result against the bundled reference volume (-c), mirroring 02-test-run.sh. Usage:
# `docker run <img> -i <input.rct> -m LolaCUDA -s 1024 -c <reference.vol>`
ENTRYPOINT ["/bin/bash","-c","source /opt/scale/bin/scaleenv \"$GPU_ARCH\" >/dev/null 2>&1 && exec rabbitRunner-NVCC \"$@\"","--"]
CMD ["-i", "/build/rabbitct/rabbitct/RabbitInput/RabbitInput.rct", "-m", "LolaCUDA", "-s", "1024", \
     "-c", "/build/rabbitct/rabbitct/RabbitInput/Reference1024.vol"]
