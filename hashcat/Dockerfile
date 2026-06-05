FROM docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.1 AS build
ENV SCALE_LICENSE_ACCEPT=1
SHELL ["/bin/bash", "-c"]
ARG GPU_ARCH=gfx1100

COPY versions.txt /build/versions.txt
COPY util/ /build/util/
COPY hashcat/ /build/hashcat/

WORKDIR /build/hashcat
RUN source /opt/scale/bin/scaleenv ${GPU_ARCH} \
    && bash 00-clone.sh \
    && bash 01-build.sh

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.1
ENV SCALE_LICENSE_ACCEPT=1
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
ENV CUDA_PATH=/opt/scale

# Copy the built hashcat directory (binary + modules/ + OpenCL/ + kernels/).
# Hashcat resolves support files relative to the working directory at runtime,
# so WORKDIR is set to the build dir to keep paths consistent.
COPY --from=build /build/hashcat/build /build/hashcat/build

ENV PATH="/opt/scale/bin:/build/hashcat/build:${PATH}"
# Both SCALE dirs are needed: targets/<arch>/lib has libredscale; lib64 has CUDA API libs.
ENV LD_LIBRARY_PATH="/opt/scale/targets/${GPU_ARCH}/lib:/opt/scale/lib64"

# Hashcat looks for modules/, OpenCL/, and kernels/ next to itself.
WORKDIR /build/hashcat/build

# `docker run <img> --help` or `docker run <img> -m 1400 -b` to benchmark.
ENTRYPOINT ["/bin/bash","-c","source /opt/scale/bin/scaleenv \"$GPU_ARCH\" >/dev/null 2>&1 && exec hashcat \"$@\"","--"]
CMD ["--help"]
