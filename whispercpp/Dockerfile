FROM docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.1 AS build
ENV SCALE_LICENSE_ACCEPT=1
SHELL ["/bin/bash", "-c"]
ARG GPU_ARCH=gfx1100

COPY versions.txt /build/versions.txt
COPY util/ /build/util/
COPY whispercpp/ /build/whispercpp/

WORKDIR /build/whispercpp
RUN source /opt/scale/bin/scaleenv ${GPU_ARCH} \
    && bash 00-clone.sh \
    && bash 01-build.sh

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.1
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
