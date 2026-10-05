#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# no -fatbin in scale (coming soon? remove when landed)
grep -q 'cuda_compile_fatbin(GPU_GEN_OBJS' lammps/cmake/Modules/Packages/GPU.cmake \
    || { echo "01-patch.sh: cuda_compile_fatbin(GPU_GEN_OBJS not found in GPU.cmake" >&2; exit 1; }
sed -i 's/cuda_compile_fatbin(GPU_GEN_OBJS/cuda_compile_cubin(GPU_GEN_OBJS/' \
    lammps/cmake/Modules/Packages/GPU.cmake

# name clash as lib/gpu/lal_precision.h renames int2 -> _lgpu_int2 when not def USE_HIP
# But GPU.cmake defines USE_CUDA (not USE_CUDART, which does get checked for
python3 - <<'PYEOF'
path = "lammps/lib/gpu/lal_precision.h"
with open(path) as f:
    content = f.read()
old = """#ifndef USE_HIP
#ifndef int2
#define int2 _lgpu_int2
#endif
#endif"""
new = """#ifndef USE_HIP
#ifdef USE_CUDA
/* NVIDIA's cuda.h doesn't declare int2 (SCALE's does), so pull it in explicitly */
#include <vector_types.h>
#else
#ifndef int2
#define int2 _lgpu_int2
#endif
#endif
#endif"""
n = content.count(old)
assert n == 1, f"expected exactly one match for the int2 block, found {n}"
with open(path, "w") as f:
    f.write(content.replace(old, new))
PYEOF

# these fixtures fail under FMA contraction (CI builds -march=x86-64-v3); skip the CPU "plain" case only.
# Fixed upstream in LAMMPS, but not yet in latest stable v:
# can drop this once we move to a newer version with the commits below
python3 - <<'PYEOF'
import re
tests = [
    # velocity ... loop geom hashes coordinate bits; 1ulp from FMA -> different velocities (4.7 A/ps)
    # https://github.com/lammps/lammps/commit/45828ff (fixture fixed), .../commit/668d803 (unstable tag dropped)
    "atomic-pair-edip.yaml",
    # plain rounding noise: 3.9e-14 vs epsilon 5e-14, upstream raised it to 1e-13
    # https://github.com/lammps/lammps/commit/f82173d (PR #5212)
    "atomic-pair-meam_spline.yaml",
    # same loop geom hash as edip; upstream regenerated this fixture 2026-09-14, probably in
    # https://github.com/lammps/lammps/commit/45828ff (not confirmed), tolerance 5e-13 -> 2e-12 there too
    "atomic-pair-meam_sw_spline.yaml",
]
for name in tests:
    path = f"lammps/unittest/force-styles/tests/{name}"
    with open(path) as f:
        content = f.read()
    content, n = re.subn(r"^skip_tests:[ ]*$", "skip_tests: plain", content, flags=re.M)
    assert n == 1, f"expected one empty skip_tests line in {name}, found {n}"
    with open(path, "w") as f:
        f.write(content)
PYEOF
