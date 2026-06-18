#!/bin/bash

set -e

cd RabbitCT

# Copied from their mk/config-default.mk but need a few overriding
# options to stop a few build errors
cat <<- EOF > config.mk
TOOLCHAIN = NVCC
ENABLE_CUDA = true
CPPFLAGS = 
SIMD = AVX512

OPTIONS +=  -DARRAY_ALIGNMENT=64
OPTIONS +=  -DSIMD_NAME=\"\$(SIMD)\"
OPTIONS +=  -DMAX_NUM_THREADS=32

ifeq (\$(SIMD), SSE)
OPTIONS +=  -DVECTORSIZE=4
endif
ifeq (\$(SIMD), AVX)
OPTIONS +=  -DVECTORSIZE=8
endif
ifeq (\$(SIMD), AVX512)
OPTIONS +=  -DVECTORSIZE=16
endif
ifeq (\$(SIMD), NEON)
OPTIONS +=  -DVECTORSIZE=4
endif
EOF

make info

make -j"$(nproc)" CFLAGS="-O3 -g"