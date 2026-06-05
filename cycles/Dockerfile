ARG SCALE_BASE_IMAGE=docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.1

FROM ${SCALE_BASE_IMAGE} AS build
USER root
ENV SCALE_LICENSE_ACCEPT=1
SHELL ["/bin/bash", "-c"]
ARG GPU_ARCH=gfx1100

# Build dependencies.
# glog headers are required even though we link against the bundled libglog_ubuntu.a.
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    git-lfs \
    libgoogle-glog-dev libgflags-dev \
    libpng-dev libjpeg-dev libtiff-dev \
    libboost-filesystem-dev libboost-system-dev libboost-thread-dev \
    libboost-date-time-dev libboost-iostreams-dev \
    libopencolorio-dev \
    libopenimageio-dev \
    && rm -rf /var/lib/apt/lists/*

COPY versions.txt /build/versions.txt
COPY util/ /build/util/
COPY cycles/ /build/cycles/

# 00-clone.sh also initialises the lib/linux_x64 submodule (precompiled CUDA PTX libs).
WORKDIR /build/cycles
RUN source /opt/scale/bin/scaleenv ${GPU_ARCH} \
    && bash 00-clone.sh \
    && bash 01-patch.sh \
    && bash 02-build.sh

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM ${SCALE_BASE_IMAGE}
USER root
ENV SCALE_LICENSE_ACCEPT=1
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
ENV CUDA_PATH=/opt/scale

# Runtime libs that the cycles binary links against.
# Note: glog is statically linked via libglog_ubuntu.a, so no runtime glog dep.
# devel base provides nvcc so Cycles NVRTC (which shells out to nvcc) works at runtime.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libboost-filesystem1.83.0 libboost-system1.83.0 libboost-thread1.83.0 \
    libboost-date-time1.83.0 libboost-iostreams1.83.0 \
    libpng16-16t64 libjpeg8 \
    libopencolorio2.1t64 \
    libgflags2.2 \
    libopenimageio2.4t64 \
    python3 \
    imagemagick \
    && rm -rf /var/lib/apt/lists/*

# Copy the installed cycles binary and the bundled example scenes.
COPY --from=build /build/cycles/install /build/cycles/install
COPY --from=build /build/cycles/cycles/examples /build/cycles/cycles/examples

ENV PATH="/opt/scale/bin:/build/cycles/install:${PATH}"
# Both SCALE dirs are needed: targets/<arch>/lib has libredscale (NVRTC locates nvcc relative to it);
# lib64 has CUDA API libs. scaleenv sets the authoritative env for CI-parity.
ENV LD_LIBRARY_PATH="/opt/scale/targets/${GPU_ARCH}/lib:/opt/scale/lib64"

WORKDIR /work

# Usage: `docker run <img> <scene.xml> --device CUDA --output out.png`
# Bundled scenes are at /build/cycles/cycles/examples/scene_*.xml
ENTRYPOINT ["/bin/bash","-c","source /opt/scale/bin/scaleenv \"$GPU_ARCH\" >/dev/null 2>&1 && exec cycles \"$@\"","--"]
CMD ["--help"]
