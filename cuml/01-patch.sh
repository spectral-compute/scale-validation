#!/bin/bash

set -ETeuo pipefail

# Repo-source patch (not SCALE-specific): in this cuML checkout
# cpp/src/glm/qn/qn_solvers.cuh defaults `rapids_logger::level_enum verbosity = 0`,
# but level_enum is `enum class : int32_t`, so `= 0` is ill-formed C++ (a
# cuML/rapids_logger version skew). Use the enumerator (underlying value 0).
sed -i -E 's/(rapids_logger::level_enum verbosity) = 0\)/\1 = rapids_logger::level_enum::trace)/' \
    cuml/cpp/src/glm/qn/qn_solvers.cuh
