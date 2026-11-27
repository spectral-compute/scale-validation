#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The tests look for their data files under OPENCV_TEST_DATA_PATH.
OPENCV_TEST_DATA_PATH="$(pwd)/opencv_extra/testdata"
export OPENCV_TEST_DATA_PATH

# The NVIDIA Optical Flow regression tests compare the hardware optical
# flow engine's output exactly against golden files. They fail with
# NVIDIA's nvcc too: the output differs on newer GPUs, and opencv_extra
# has no nvofGolden_2.flo for the 2.0 API.
FILTER="-*NvidiaOpticalFlow_1_0.Regression*:*NvidiaOpticalFlow_2_0.Regression*"

RETCODE=0
BROKEN=()
for T in "$(pwd)"/install/bin/opencv_test_cuda*; do
    log "$(basename "$T")"

    set +e
    (cd "opencv_extra/testdata/gpu" && "$T" --gtest_filter="$FILTER")
    R=$?
    set -e

    if [ "$R" != "0" ]; then
        BROKEN+=("$T")
        RETCODE=2
    fi
done

echo -e "${BROKEN[@]}"
exit $RETCODE
