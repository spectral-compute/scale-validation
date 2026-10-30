#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone HARD https://github.com/lanl/HARD.git "$(get_version HARD)"
do_clone flecsi https://github.com/flecsi/flecsi.git "$(get_version HARD-flecsi)"
do_clone flecsolve https://github.com/lanl/flecsolve.git "$(get_version HARD-flecsolve)"

# Its submodules also provide the Kokkos, Eigen, spiner and ports-of-call everything else uses.
do_clone singularity-eos https://github.com/lanl/singularity-eos.git "$(get_version HARD-singularity-eos)"

# FleCSI needs Boost.ProgramOptions.
BOOST_VERSION="$(get_version HARD-boost)"
if [ ! -d boost ]; then
    wget -nv -O - "https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION//./_}.tar.bz2" |
        tar -xj
    mv "boost_${BOOST_VERSION//./_}" boost
fi
