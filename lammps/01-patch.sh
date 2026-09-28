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
#ifndef USE_CUDA
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
