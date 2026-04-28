#!/bin/bash

set -e
cd "${OUT_DIR}/alien/build"

export LD_LIBRARY_PATH="${CUDA_PATH}/lib"

export SCALE_NONFATAL_EXCEPTIONS=1
./EngineTests --gtest_filter=-DataTransferTests.largeData:MutationTests.insertMutation_emptyGenome
./NetworkTests
unset SCALE_NONFATAL_EXCEPTIONS
