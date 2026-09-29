#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

source "$(dirname "$0")"/../util/checks.sh

# Renders the SCALE company logo/text as densely-packed LAMMPS particles
# (Gay-Berne ellipsoids) settling and colliding, then stitches the frames into
# an MP4 -- a branding animation, not a physics validation example. The full
# pipeline (layout generation, LAMMPS data file, the LAMMPS input itself) lives
# in scale-lammps-animation/; see that directory's README.md. This script is
# mainly just a thin wrapper around its run_animation.sh orchestrator.
#
# gayberne has no KOKKOS-accelerated variant (checked against
# docs.lammps.org's pair_gayberne page: gpu/intel/omp only, no kk) -- so this
# animation only lives here, under the GPU package, not in lammps-kokkos/.
#
# Needs the LAMMPS build configured with -DPKG_ASPHERE=yes (pair_style
# gayberne, atom_style ellipsoid, fix nve/asphere) and -DPKG_GRAPHICS=yes
# (dump image) -- see 02-build.sh.
#
# Heavy: the default parameters render 600+ frames at 1920x1080 with
# full-scene anti-aliasing, and dump image's ray tracing isn't itself
# GPU-accelerated regardless of pair style, so this takes real minutes to
# run. That's fine for a one-off render but not something to do on every
# automated test.sh pass, so unlike 06-animated-example.sh this script is
# gated behind an explicit --run and is otherwise a harmless no-op --
# test.sh will still "run" this file every time, it'll just skip straight
# past. Generate the video by hand with:
#   ./07-animated-scale.sh --run
if [ "${1:-}" != "--run" ]; then
    echo "skipping scale-lammps-animation (not part of the automated suite -- run '$0 --run' by hand to generate it)"
    exit 0
fi

ANIM_DIR="$(dirname "$0")/scale-lammps-animation"
LMP="$(pwd)/build/lmp"
MOVIE_NAME="scale_animation.mp4"

# Same as 06-animated-example.sh's ensure_ffmpeg -- duplicated rather than
# shared, matching how the rest of this suite handles per-file helpers.
# 06 runs first and already installs it, so this is only a fallback for
# running this script standalone.
ensure_ffmpeg() {
    command -v ffmpeg > /dev/null 2>&1 && return 0
    echo "ffmpeg not found on PATH; installing..."
    [ "$(id -u)" = "0" ] || { echo "not root and ffmpeg is missing -- can't apt-get install" >&2; return 1; }
    command -v apt-get > /dev/null 2>&1 || { echo "no apt-get available to install ffmpeg" >&2; return 1; }
    apt-get update -qq && apt-get install -y --no-install-recommends ffmpeg
}

check_run() {
    # Output (log, screen log, runs/) lands in the current directory, which is
    # test.sh's WORKDIR/lammps -- wiped on the next run of test.sh unless you
    # pass --keep.
    #
    # "neigh no" same as 06-animated-example.sh's check_run -- this system mixes
    # ellipsoid and sphere-style atoms, which the GPU package's on-device neighbor
    # build rejects outright ("CPU neighbor lists must be used for ellipsoid/sphere
    # mix", src/GPU/gpu_extra.h:80); falls back to LAMMPS's own CPU-built neighbor
    # lists, offloading only the force calc.
    ensure_ffmpeg \
        && LAMMPS_BIN="${LMP}" \
           OUT_ROOT="$(pwd)/scale-animation-runs" \
           RUN_NAME="run" \
           VIDEO_NAME="${MOVIE_NAME}" \
               "${ANIM_DIR}/run_animation.sh" -sf gpu -pk gpu 1 neigh no \
               > scale-animation.screen.log 2>&1
}

# Same gotcha as 06-animated-example.sh's check_gpu_suffix_in_use: the device
# banner proving GPU acceleration only ever goes to the screen stream, never
# the -log file.
check_gpu_suffix_in_use() {
    grep -F 'Using acceleration for gayberne:' scale-animation.screen.log
}

check_movie_made() {
    [ -s "scale-animation-runs/run/${MOVIE_NAME}" ]
}

check "scale animation: ran to completion under the GPU package" check_run
check "scale animation ran the gayberne/gpu style, not a CPU fallback" check_gpu_suffix_in_use
check "scale animation: ffmpeg stitched the frames into ${MOVIE_NAME}" check_movie_made

check_exit
