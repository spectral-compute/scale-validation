#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# cuPHY lives in NVIDIA's Aerial monorepo. Its LFS objects are test data and the 5GModel wheel; only
# 03-gen-vectors.sh needs the latter, and fetches it itself.
GIT_LFS_SKIP_SMUDGE=1 do_clone aerial https://github.com/NVIDIA/aerial-cuda-accelerated-ran.git "$(get_version cuPHY)"

# Dependencies Aerial's container installs (see cuPHY-CP/container/aerial_base_recipe.py).
do_clone libyaml https://github.com/yaml/libyaml.git "$(get_version cuPHY-libyaml)"
do_clone yaml-cpp https://github.com/jbeder/yaml-cpp.git "$(get_version cuPHY-yaml-cpp)"
do_clone fmt https://github.com/fmtlib/fmt.git "$(get_version cuPHY-fmt)"
do_clone fmtlog https://github.com/MengRao/fmtlog.git "$(get_version cuPHY-fmtlog)"
do_clone CLI11 https://github.com/CLIUtils/CLI11.git "$(get_version cuPHY-CLI11)"
do_clone gsl-lite https://github.com/gsl-lite/gsl-lite.git "$(get_version cuPHY-gsl-lite)"
do_clone wise_enum https://github.com/quicknir/wise_enum.git "$(get_version cuPHY-wise_enum)"
# Only built if the system has no HDF5 (see 02-build.sh).
if [[ ! -e /usr/include/hdf5/serial/hdf5.h && ! -e /usr/include/hdf5.h ]]; then
    do_clone hdf5 https://github.com/HDFGroup/hdf5.git "$(get_version cuPHY-hdf5)"
fi

# cuFFTDx (header-only).
MATHDX="$(get_version cuPHY-mathdx)"
if [[ ! -d mathdx ]]; then
    mkdir mathdx
    curl -fsSL "https://developer.download.nvidia.com/compute/cuFFTDx/redist/cuFFTDx/nvidia-mathdx-${MATHDX}.tar.gz" |
        tar -xz -C mathdx --strip-components=1
fi
