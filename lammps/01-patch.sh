#!/bin/bash

set -e

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

# nvd_device.h queries every device attr at startup and aborts if not succeeding.
# but SCALE 1.7.3 doesn't implement CU_DEVICE_ATTRIBUTE_MAX_PITCH
# But it's safe to  just patch default memPitch to 0 here: max_pitch() is only used for an info dump
# and LAMMPS's OpenCL backend already hardcodes it to 0
python3 - <<'PYEOF'
path = "lammps/lib/gpu/geryon/nvd_device.h"
with open(path) as f:
    content = f.read()
old = "    CU_SAFE_CALL_NS(cuDeviceGetAttribute(&prop.memPitch, CU_DEVICE_ATTRIBUTE_MAX_PITCH, dev));"
new = """    {
      CUresult pitch_err = cuDeviceGetAttribute(&prop.memPitch, CU_DEVICE_ATTRIBUTE_MAX_PITCH, dev);
      if (pitch_err == CUDA_ERROR_NOT_SUPPORTED) {
        prop.memPitch = 0;
      } else if (pitch_err != CUDA_SUCCESS) {
        fprintf(stderr, "Cuda driver error %d in call at file '%s' in line %i.\\n",
                pitch_err, __FILE__, __LINE__);
        NVD_GERYON_EXIT;
      }
    }"""
n = content.count(old)
assert n == 1, f"expected exactly one match for the memPitch query, found {n}"
with open(path, "w") as f:
    f.write(content.replace(old, new))
PYEOF
