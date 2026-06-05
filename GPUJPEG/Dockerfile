FROM docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.1 AS build
ENV SCALE_LICENSE_ACCEPT=1
SHELL ["/bin/bash", "-c"]
ARG GPU_ARCH=gfx1100

RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    && rm -rf /var/lib/apt/lists/*

COPY versions.txt /build/versions.txt
COPY util/ /build/util/
COPY GPUJPEG/ /build/GPUJPEG/

WORKDIR /build/GPUJPEG
RUN source /opt/scale/bin/scaleenv ${GPU_ARCH} \
    && bash 00-clone.sh \
    && bash 01-patch.sh \
    && bash 02-build.sh

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.1
ENV SCALE_LICENSE_ACCEPT=1
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
ENV CUDA_PATH=/opt/scale

# Copy the built binaries and shared library.
COPY --from=build /build/GPUJPEG/build /build/GPUJPEG/build

ENV PATH="/opt/scale/bin:/build/GPUJPEG/build:${PATH}"
# Both SCALE dirs are needed: targets/<arch>/lib has libredscale; lib64 has CUDA API libs.
ENV LD_LIBRARY_PATH="/opt/scale/targets/${GPU_ARCH}/lib:/opt/scale/lib64:/build/GPUJPEG/build"

WORKDIR /work

# gpujpegtool takes positional input/output: `gpujpegtool --encode in.ppm out.jpg`
# `docker run <img> --encode in.ppm out.jpg` to encode (mount files via -v).
# `docker run <img> --decode in.jpg out.ppm` to decode.
ENTRYPOINT ["/bin/bash","-c","source /opt/scale/bin/scaleenv \"$GPU_ARCH\" >/dev/null 2>&1 && exec gpujpegtool \"$@\"","--"]
CMD ["--help"]
