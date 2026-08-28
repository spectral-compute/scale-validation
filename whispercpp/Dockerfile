ARG SCALE_BASE_IMAGE=docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.2

FROM ${SCALE_BASE_IMAGE} AS build
USER root
ENV SCALE_LICENSE_ACCEPT=1
SHELL ["/bin/bash", "-c"]
ARG GPU_ARCH=gfx1100

COPY versions.txt /build/versions.txt
COPY util/ /build/util/
COPY whispercpp/ /build/whispercpp/
COPY test.sh /build/test.sh

# Runs the clone/build scripts via the same test.sh driver used below.
# --keep is required here: without it test.sh would rm -rf /build/whispercpp
# (its own OUT_DIR/TEST_NAME) before globbing scripts from that very directory.
WORKDIR /build
RUN bash test.sh /build /opt/scale "${GPU_ARCH}" whispercpp --match '-(clone|patch|build)' --keep

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
ENTRYPOINT ["/bin/bash", "-c", "exec bash /build/test.sh /build /opt/scale \"$GPU_ARCH\" whispercpp --match '-(test|benchmark)' --keep"]

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM ${SCALE_BASE_IMAGE}
USER root
ENV SCALE_LICENSE_ACCEPT=1
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
ENV CUDA_PATH=/opt/scale

COPY --from=build /build/whispercpp/build/bin   /build/whispercpp/build/bin
COPY --from=build /build/whispercpp/build/src   /build/whispercpp/build/src
COPY --from=build /build/whispercpp/build/ggml/src \
                  /build/whispercpp/build/ggml/src

# Bundle the model download script and sample audio files.
COPY --from=build /build/whispercpp/whispercpp/models  /build/whispercpp/whispercpp/models
COPY --from=build /build/whispercpp/whispercpp/samples /build/whispercpp/whispercpp/samples

ENV PATH="/opt/scale/bin:/build/whispercpp/build/bin:${PATH}"
# Both SCALE dirs are needed: targets/<arch>/lib has libredscale; lib64 has CUDA API libs (libcublas etc.)
# scaleenv sets the authoritative env; the baked values cover --entrypoint overrides that bypass the wrapper.
ENV LD_LIBRARY_PATH="/opt/scale/targets/${GPU_ARCH}/lib:/opt/scale/lib64:/build/whispercpp/build/src:/build/whispercpp/build/ggml/src"

WORKDIR /work

# `docker run <img> -m /models/ggml-base.en.bin -f audio.wav` mirrors native use.
# At pinned ref v1.7.1 the CLI binary is named `main` (whisper-cli was introduced later).
# Source scaleenv so CUDA_PATH, CUDAARCHS, and LD_LIBRARY_PATH match CI exactly (Cycles NVRTC → nvcc).
ENTRYPOINT ["/bin/bash","-c","source /opt/scale/bin/scaleenv \"$GPU_ARCH\" >/dev/null 2>&1 && exec main \"$@\"","--"]
CMD ["--help"]
