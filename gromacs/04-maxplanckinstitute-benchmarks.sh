#!/bin/bash

set -e

# Download the benchmark data if it doesn't already exist.
OUT_DIR=$(realpath .)
mkdir -p "data/MaxPlanckInstituteGromacsBenchmarks"
cd "data/MaxPlanckInstituteGromacsBenchmarks"

for URL in https://data.spectralcompute.co.uk/gromacs/benchMEM.zip \
           https://data.spectralcompute.co.uk/gromacs/benchPEP.zip \
           https://data.spectralcompute.co.uk/gromacs/benchRIB.zip \
           https://data.spectralcompute.co.uk/gromacs/benchBFC.zip \
           https://data.spectralcompute.co.uk/gromacs/benchBFI.zip \
           https://data.spectralcompute.co.uk/gromacs/benchBNC.zip \
           https://data.spectralcompute.co.uk/gromacs/benchBNI.zip \
           https://data.spectralcompute.co.uk/gromacs/benchBTC.zip \
           https://data.spectralcompute.co.uk/gromacs/benchBTI.zip \
           https://data.spectralcompute.co.uk/gromacs/benchSFC.zip \
           https://data.spectralcompute.co.uk/gromacs/benchSFI.zip \
           https://data.spectralcompute.co.uk/gromacs/benchSNC.zip \
           https://data.spectralcompute.co.uk/gromacs/benchSNI.zip \
           https://data.spectralcompute.co.uk/gromacs/benchSTC.zip \
           https://data.spectralcompute.co.uk/gromacs/benchSTI.zip ; do
    if [ ! -e "$(echo "${URL}" | sed -E 's;.*/;;')" ] ; then
        wget "${URL}"
    fi
done
cd -

# Create somewhere for results.
RESULT_FILE="${OUT_DIR}/$(basename -s .sh "$0").csv"
rm -f "${RESULT_FILE}"

RESULT_DIR="${OUT_DIR}/benchmarks/MaxPlanckInstitute"
mkdir -p "${RESULT_DIR}"

# Run all the tests.
RETCODE=0
source "./install/bin/GMXRC"
for ZIP in "${OUT_DIR}/data/MaxPlanckInstituteGromacsBenchmarks/"*.zip ; do
    NAME="$(basename -s .zip "${ZIP}")"

    # Clear a directory for the test.
    rm -rf "${RESULT_DIR}/${NAME}"
    mkdir "${RESULT_DIR}/${NAME}"
    cd "${RESULT_DIR}/${NAME}"

    # Some tests want special treatment.
    EXTRA_ARGS=
    case "${NAME}" in
        benchBFI)
            # The default is too slow for this benchmark.
            EXTRA_ARGS="-nsteps 2500"
        ;;
        benchPEP)
            # The default is too slow for this benchmark. So much so that this probably actually has a significant
            # amount of overhead (10 steps are not 10 times faster than 100).
            EXTRA_ARGS="-nsteps 100"
        ;;
        benchRIB)
            # The default is too slow for this benchmark.
            EXTRA_ARGS="-nsteps 500"
        ;;
        benchSFC)
            # The default is a little fast for this benchmark.
            EXTRA_ARGS="-nsteps 20000"
        ;;
        benchSNC)
            # The default is a little fast for this benchmark.
            EXTRA_ARGS="-nsteps 100000"
        ;;
        benchSNI)
            # The default is a little fast for this benchmark.
            EXTRA_ARGS="-nsteps 100000"
        ;;
        benchSTC)
            # This benchmark doesn't work (with NVCC or Clang).
            continue
        ;;
        benchSTI)
            # This benchmark doesn't work (with NVCC or Clang).
            continue
        ;;
    esac

    # Actually extract and run the test.
    unzip "${ZIP}"
    set +e
    #gmx mdrun -s "${NAME}.tpr" ${EXTRA_ARGS} -ntmpi 1 -pme cpu -bonded cpu -update cpu
    gmx mdrun -s "${NAME}.tpr" ${EXTRA_ARGS} -ntmpi 1 -nb gpu
    if [ "$?" != 0 ] ; then
        set -e
        RETCODE=2
        echo "MPG${NAME},status,fail" >> "${RESULT_FILE}"
        continue
    fi
    set -e

    # Record the result.
    echo "MPG${NAME},status,success" >> "${RESULT_FILE}"
    echo "MPG${NAME},time,$(cat md.log | grep 'Time:' | sed -E 's/ +/ /g' | cut -d ' ' -f 4)" >> "${RESULT_FILE}"
done

# Pretty print the results.
sed -E 's/(.*),status,(.*)/\1: \2/;s/(.*),time,(.*)/\1: \2 s/' "${RESULT_FILE}"

# Done :)
exit ${RETCODE}
