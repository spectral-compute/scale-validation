ARG SCALE_BASE_IMAGE=docker.io/spectralcompute/scale:13.0.2-devel-ubuntu24.04-1.7.2

FROM ${SCALE_BASE_IMAGE} AS build
USER root
ENV SCALE_LICENSE_ACCEPT=1
SHELL ["/bin/bash", "-c"]
ARG GPU_ARCH=gfx1100

# curl is needed by vcpkg's own bootstrap script (invoked transitively via
# alien's CMakeLists.txt during the build step below), not just by the
# Forgejo Actions runner's step-completion reporting in the test stage.
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
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
COPY alien/ /build/alien/
COPY test.sh /build/test.sh

# alien's own CMakeLists.txt wires up vcpkg to fetch/build its C++ dependencies;
# vcpkg itself is vendored as a submodule fetched by 00-clone.sh's recursive
# clone, so no separate vcpkg install step is needed here -- just network access
# during the build (available at `docker build` time, unlike the test stage's
# GPU access).
# Runs the clone/patch/build scripts via the same test.sh driver used below.
# --keep is required here: without it test.sh would rm -rf /build/alien (its
# own OUT_DIR/TEST_NAME) before globbing scripts from that very directory.
WORKDIR /build
RUN bash test.sh /build /opt/scale "${GPU_ARCH}" alien --match '-(clone|patch|build)' --keep

# ── test stage ─────────────────────────────────────────────────────────────
# Runs only the test/benchmark scripts (matched by filename, not hardcoded)
# against the project dir the build stage already cloned+built above.
FROM build AS test
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
# curl (needed by the Forgejo Actions runner itself to report step completion,
# https://github.com/nektos/act/issues/107) is already installed in the build
# stage above for vcpkg's bootstrap script, so nothing to add here.
ENTRYPOINT ["/bin/bash", "-c", "exec bash /build/test.sh /build /opt/scale \"$GPU_ARCH\" alien --match '-(test|benchmark)' --keep"]

# ── runtime stage ─────────────────────────────────────────────────────────────
FROM ${SCALE_BASE_IMAGE}
USER root
ENV SCALE_LICENSE_ACCEPT=1
ARG GPU_ARCH=gfx1100
ENV GPU_ARCH=${GPU_ARCH}
ENV CUDA_PATH=/opt/scale

# ALIEN's top-level CMakeLists.txt builds 4 executables: the "alien" GUI, the
# headless "cli" runner, and EngineTests/NetworkTests. Only "cli" is a real,
# usable-without-a-display CLI binary, so it's what the runtime entrypoint below
# uses; the GUI needs a window/display and isn't shipped. EngineTests/NetworkTests
# are copied too so `--entrypoint` can still reach the engine's own validation
# suites directly (see README).
COPY --from=build /build/alien/build/cli          /build/alien/build/cli
COPY --from=build /build/alien/build/EngineTests   /build/alien/build/EngineTests
COPY --from=build /build/alien/build/NetworkTests  /build/alien/build/NetworkTests

# Bundled sample simulation ("autosave.sim" + its "autosave.settings.json", read
# by SerializerService via extension-swapping on the same base filename) that
# ships in the upstream source tree at resources/, used as the default input for
# the "try it" demo below.
COPY --from=build /build/alien/alien/resources/autosave.sim \
                   /build/alien/alien/resources/autosave.settings.json \
                   /build/alien/resources/

ENV PATH="/opt/scale/bin:/build/alien/build:${PATH}"
# Both SCALE dirs are needed: targets/<arch>/lib has libredscale; lib64 has CUDA API libs.
ENV LD_LIBRARY_PATH="/opt/scale/targets/${GPU_ARCH}/lib:/opt/scale/lib64:/build/alien/build"

WORKDIR /work

# `docker run <img> -i /build/alien/resources/autosave.sim -o /tmp/out.sim -t 1000`
# mirrors native `cli` use: it loads the bundled sample simulation, runs it for
# the given number of timesteps entirely on the GPU (via EngineImpl/EngineGpuKernels,
# the same engine core EngineTests/NetworkTests validate), prints the detected GPU
# and achieved timesteps-per-second, and writes the resulting simulation state back
# out. CMD below bakes in a real run against the bundled sample so `docker run`
# with no arguments produces real GPU-execution output out of the box.
ENTRYPOINT ["/bin/bash","-c","source /opt/scale/bin/scaleenv \"$GPU_ARCH\" >/dev/null 2>&1 && exec cli \"$@\"","--"]
CMD ["-i", "/build/alien/resources/autosave.sim", "-o", "/tmp/alien-out.sim", "-t", "1000"]
