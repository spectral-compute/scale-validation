#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

if [ ! -e "${OUT_DIR}/openmpi/install" ] ; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

export PATH="${OUT_DIR}/openmpi/install/bin:${PATH}"
export LD_LIBRARY_PATH="${OUT_DIR}/openmpi/install/lib:${LD_LIBRARY_PATH}"

# Amusing hack to make it use the SCALE MPI.
export NCAR_ROOT_MPI=${OUT_DIR}/openmpi/install

if [ -z $NCAR_ROOT_MPI ]; then
  echo "Run the openmpi script first"
fi

cd "${OUT_DIR}/FastEddy/FastEddy/SRC/FEMAIN"
make
