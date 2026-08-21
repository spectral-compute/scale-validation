#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

function buildExample() {
    args=(
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
        -DCMAKE_INSTALL_PREFIX="install"
    )

    cmake \
        "${args[@]}" \
        -B"cublas_$2" \
        "CUDALibrarySamples/$1/$2"

    make -C "cublas_$2" install -j"$(nproc)"

}

for i in amax amin asum axpy copy dot nrm2 rot rotg rotm rotmg scal swap; do
    buildExample "cuBLAS/Level-1/" $i
done

for i in gbmv ger hemv her2 hpr sbmv spr symv syr2 tbsv tpsv trsv gemv hbmv her hpmv hpr2 spmv spr2 syr tbmv tpmv trmv; do
    buildExample "cuBLAS/Level-2/" $i
done

for i in gemm gemmBatched gemmStridedBatched her2k herkx syr2k trsm hemm herk symm syrk trmm trsmBatched; do
    # TODO: re-enable syrkx, gemm3m and gemmGroupedBatched once implemented
    buildExample "cuBLAS/Level-3/" $i
done
