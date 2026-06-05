FROM docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.1 AS build
ENV SCALE_LICENSE_ACCEPT=1
SHELL ["/bin/bash", "-c"]
ARG GPU_ARCH=gfx1100

RUN apt-get update && apt-get install -y --no-install-recommends \
    libprotobuf-dev protobuf-compiler libboost-all-dev \
    libgflags-dev libgoogle-glog-dev libhdf5-dev libopenblas-dev \
    liblmdb-dev \
    libleveldb-dev \
    libsnappy-dev \
    && rm -rf /var/lib/apt/lists/*

COPY versions.txt /build/versions.txt
COPY util/ /build/util/
COPY caffe/ /build/caffe/

# Caffe installs to $(pwd)/../install relative to WORKDIR = /build/install.
WORKDIR /build/caffe
RUN source /opt/scale/bin/scaleenv ${GPU_ARCH} \
    && unset GPU_ARCH \
    && bash 00-clone.sh \
    && bash 01-patch.sh \
    && bash 02-build.sh

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.1
ENV SCALE_LICENSE_ACCEPT=1
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
ENV CUDA_PATH=/opt/scale

RUN apt-get update && apt-get install -y --no-install-recommends \
    libopenblas0 \
    libprotobuf32t64 \
    libboost-system1.83.0 \
    libboost-filesystem1.83.0 \
    libboost-thread1.83.0 \
    libgflags2.2 \
    libgoogle-glog0v6t64 \
    libhdf5-103-1t64 \
    libhdf5-hl-100t64 \
    liblmdb0 \
    libleveldb1d \
    libsnappy1v5 \
    && rm -rf /var/lib/apt/lists/*

# Copy the installed Caffe binaries and libraries.
COPY --from=build /build/install /build/install

ENV PATH="/opt/scale/bin:/build/install/bin:${PATH}"
# Both SCALE dirs are needed: targets/<arch>/lib has libredscale; lib64 has CUDA API libs.
ENV LD_LIBRARY_PATH="/opt/scale/targets/${GPU_ARCH}/lib:/opt/scale/lib64:/build/install/lib"

WORKDIR /work

# `docker run <img> device_query` or `docker run <img> train -solver=…` mirrors native Caffe CLI use.
ENTRYPOINT ["/bin/bash","-c","source /opt/scale/bin/scaleenv \"$GPU_ARCH\" >/dev/null 2>&1 && exec caffe \"$@\"","--"]
CMD ["--help"]
