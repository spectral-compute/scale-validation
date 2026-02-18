#!/bin/bash

set -e

OUT_DIR=$(realpath ../)
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

make -C FastEddy/SRC/FEMAIN
