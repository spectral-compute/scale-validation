#!/usr/bin/env bash
set -euo pipefail
# HeCBench requires `dvc` as part of its data management
#
# You can install this via `pipx`:
#   sudo apt install -y pipx
#   pipx ensurepath
#   pipx install dvc
#   pipx inject dvc dvc-s3
#
# or `uv`:
#   curl -LsSf https://astral.sh/uv/install.sh | sh
#   uv tool install dvc[s3]

# TODO: What can we assume is installed on the running machine?
# TODO: Uncomment if fine to install dependencies like this,
#       else document.
# if which uv &> /dev/null; then
#     curl -LsSf https://astral.sh/uv/install.sh | sh
#     uv tool install dvc[s3]
# fi

source "$(dirname "$0")"/../util/git.sh

do_clone_hash HeCBench https://github.com/ORNL/HeCBench.git "$(get_version HeCBench)"

(
    cd HeCBench
    
    dvc pull

    # The following does not compile even for cuda-nvidia
    # TODO: Investigate if still failing
    sed -i /dp4a/d src/CMakeLists.txt

    # Compilation Failures (on gfx1201)
    # FIXME: These prevent the benchmark from compiling on gfx1201.
    sed -i /gels/d src/CMakeLists.txt
    sed -i /prefetch/d src/CMakeLists.txt
    sed -i /streamOrderedAllocation/d src/CMakeLists.txt
    sed -i /blas-fp8gemm/d src/CMakeLists.txt

    # These hang
    sed -i /cm/d src/CMakeLists.txt
    sed -i /divergence/d src/CMakeLists.txt
    sed -i /ising/d src/CMakeLists.txt
    sed -i /mdh/d src/CMakeLists.txt
    sed -i /laplace/d src/CMakeLists.txt
    sed -i /logic-rewrite/d src/CMakeLists.txt

)
