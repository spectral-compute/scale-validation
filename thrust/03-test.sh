#!/bin/bash

set -ETeuo pipefail

ctest --test-dir build --output-on-failure --output-junit thrust.xml -E "thrust.test.complex_transform|thrust.test.cuda.device_side_universal_vector.cdp_0|thrust.test.sequence|thrust.test.cuda.pair_sort_by_key.cdp_0|thrust.test.cuda.sort_by_key.cdp_0"
