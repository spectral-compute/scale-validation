#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

source "$(dirname "$0")"/../util/checks.sh

# stop it running in CI, it's mainly for manual use
if [ "${1:-}" != "--run" ]; then
    echo "skipping scale-lammps-animation (not part of the automated suite -- run '$0 --run' by hand to generate it)"
    exit 0
fi

# Runs LAMMPS's bundled examples/crack (2d Lennard-Jones crack
# propagating through a solid, driven by shear at the box edges).
# Uses ffmpeg and LAMMPS' dump image to make the video.
# "dump image" needs -DPKG_GRAPHICS=yes (02-build.sh)

LMP="./build/lmp"
EXAMPLE="lammps/examples/crack/in.crack"
IN="in.crack.animated"
DUMP_EVERY=50

final_thermo() {
    local log="$1" want="$2"
    awk -v want="${want}" '
        $1 == "Step" { delete col; for (i = 1; i <= NF; i++) col[$i] = i; nc = NF; next }
        nc > 0 && NF == nc && $1 ~ /^-?[0-9]/ { for (i = 1; i <= NF; i++) row[i] = $i; next }
        /^Loop time of/ { if (want in col) last = row[col[want]]; nc = 0; next }
        END { if (last == "") exit 1; print last }
    ' "${log}"
}

approx_eq() {
    awk -v a="$1" -v e="$2" -v t="$3" 'BEGIN {
        d = a - e; if (d < 0) d = -d
        printf "  actual=%s expected=%s delta=%.6g tolerance=%s\n", a, e, d, t
        exit (d <= t) ? 0 : 1
    }'
}

# ffmpeg isn't needed for any of the standard CI-running LAMMPS files
ensure_ffmpeg() {
    command -v ffmpeg > /dev/null 2>&1 && return 0
    echo "ffmpeg not found on PATH; installing..."
    [ "$(id -u)" = "0" ] || { echo "not root and ffmpeg is missing -- can't apt-get install" >&2; return 1; }
    command -v apt-get > /dev/null 2>&1 || { echo "no apt-get available to install ffmpeg" >&2; return 1; }
    apt-get update -qq && apt-get install -y --no-install-recommends ffmpeg
}


make_animated_input() {
    [ -f "${EXAMPLE}" ] || { echo "${EXAMPLE} not found -- wrong LAMMPS checkout?" >&2; return 1; }
    local n
    # LAMMPS's stock examples use a tab, not a space, after "run" -- [[:space:]] catches both.
    n="$(grep -c '^run[[:space:]]' "${EXAMPLE}")"
    [ "${n}" = "1" ] || { echo "expected exactly one 'run' command in ${EXAMPLE}, found ${n}" >&2; return 1; }
    awk -v every="${DUMP_EVERY}" '
        /^run[[:space:]]/ && !done {
            print "dump crackimage all image " every " image.*.ppm type type zoom 1.6 adiam 1.5"
            print "dump_modify crackimage pad 4"
            done = 1
        }
        { print }
    ' "${EXAMPLE}" > "${IN}"
}

check_run() {
    # neighbor lists fall back to CPU-built? offloading only the force calc.
    make_animated_input \
        && "${LMP}" -sf gpu -pk gpu 1 neigh no -in "${IN}" -log crack.log > crack.screen.log 2>&1
}

# Checking because the device banner proving GPU use only goes to the screen stream, never the -log file.
check_gpu_suffix_in_use() {
    grep -F 'Using acceleration for lj/cut:' crack.screen.log
}

check_frames_written() {
    local steps expected n
    steps="$(awk '/^run[[:space:]]/{print $2}' "${EXAMPLE}")"
    expected=$(( steps / DUMP_EVERY + 1 ))
    n="$(ls image.*.ppm 2> /dev/null | wc -l)"
    [ "${n}" = "${expected}" ] || { echo "expected ${expected} frames, found ${n}" >&2; return 1; }
}

check_gif_made() {
    ensure_ffmpeg || return 1
    ffmpeg -y -framerate 10 -pattern_type glob -i "image.*.ppm" \
        -vf "split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" crack.gif \
        > ffmpeg.log 2>&1 || return 1
    [ -s crack.gif ]
}

check "crack: ran to completion under the GPU package" check_run
check "crack ran the lj/cut/gpu style, not a CPU fallback" check_gpu_suffix_in_use
check "crack: dump image wrote the expected number of frames" check_frames_written
check "crack: ffmpeg stitched the frames into crack.gif" check_gif_made

check_exit
