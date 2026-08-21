#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

./cuml/cpp/build/test/ml    # Single GPU algorithm tests
./cuml/cpp/build/test/ml_mg # Multi GPU algorithm tests, if --singlegpu was not used
./cuml/cpp/build/test/prims # ML Primitive function tests
