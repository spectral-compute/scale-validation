#!/bin/bash
set -e

source "$(dirname "$0")"/../util/checks.sh

# A second, genuinely different test variant, so the multi-image count
# assertion below is a real check rather than trivially always 2.
convert nvflip/images/test.png -brightness-contrast 15x0 test_variant.png

check_multi_image_invocation() {
    local out count
    out="$(./build/flip-cuda --reference nvflip/images/reference.png --test nvflip/images/test.png test_variant.png --verbosity 1)"
    echo "${out}"
    count="$(echo "${out}" | grep -icE 'Mean:')"
    echo "Mean: lines found: ${count} (expect 2, one per test image)"
    [ "${count}" -eq 2 ]
}

check_threshold_high_passes() {
    ./build/flip-cuda --reference nvflip/images/reference.png --test nvflip/images/test.png --verbosity 1 \
        --exit-on-test --exit-test-parameters mean 0.99
}

# The bundled images genuinely differ, so a nonzero exit here is correct
# behaviour -- passes iff the tool reports failure.
check_threshold_low_fails() {
    ! ./build/flip-cuda --reference nvflip/images/reference.png --test nvflip/images/test.png --verbosity 1 \
        --exit-on-test --exit-test-parameters mean 0.01
}

check "single reference vs two test images reports 2 Mean: lines" check_multi_image_invocation
check "high threshold (0.99) passes"                              check_threshold_high_passes
check "low threshold (0.01) triggers failure"                     check_threshold_low_fails

check_exit
