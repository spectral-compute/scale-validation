ARG SCALE_BASE_IMAGE=docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.1

FROM ${SCALE_BASE_IMAGE} AS build
USER root
ENV SCALE_LICENSE_ACCEPT=1
SHELL ["/bin/bash", "-c"]
ARG GPU_ARCH=gfx1100

RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    && rm -rf /var/lib/apt/lists/*

COPY versions.txt /build/versions.txt
COPY util/ /build/util/
COPY nvflip/ /build/nvflip/

WORKDIR /build/nvflip
RUN source /opt/scale/bin/scaleenv ${GPU_ARCH} \
    && bash 00-clone.sh \
    && bash 01-build.sh

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM ${SCALE_BASE_IMAGE}
USER root
ENV SCALE_LICENSE_ACCEPT=1
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
ENV CUDA_PATH=/opt/scale

# imagemagick (compare) + python3 back the CPU-vs-GPU parity check documented in
# the README; same packages cycles' runtime stage installs for the same reason.
RUN apt-get update && apt-get install -y --no-install-recommends \
    imagemagick \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binaries (both flip and flip-cuda land in build/) and the
# bundled sample images from the nested clone (00-clone.sh clones into
# nvflip/nvflip relative to the build-stage WORKDIR).
COPY --from=build /build/nvflip/build /build/nvflip/build
COPY --from=build /build/nvflip/nvflip/images /build/nvflip/images

ENV PATH="/opt/scale/bin:/build/nvflip/build:${PATH}"
# Both SCALE dirs are needed: targets/<arch>/lib has libredscale; lib64 has CUDA API libs.
ENV LD_LIBRARY_PATH="/opt/scale/targets/${GPU_ARCH}/lib:/opt/scale/lib64:/build/nvflip/build"

WORKDIR /work

# flip-cuda (GPU) is the default entrypoint; the CPU binary is reachable via
# `--entrypoint flip`. Usage: `docker run <img> -r ref.png -t test.png -v 1`
# (mount files via -v). Bundled sample images live at /build/nvflip/images/.
ENTRYPOINT ["/bin/bash","-c","source /opt/scale/bin/scaleenv \"$GPU_ARCH\" >/dev/null 2>&1 && exec flip-cuda \"$@\"","--"]
CMD ["--help"]
