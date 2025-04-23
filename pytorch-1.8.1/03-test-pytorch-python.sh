#!/bin/bash

# On Arch, try installing: sudo pacman -S python-hypothesis python-psutil python-pillow python-pytest

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/pytorch/build"

# Figure out our Python version.
PYVER=$(python3 --version | sed -E 's/Python ([0-9]+\.[0-9]+)\.[0-9]+/\1/')

# Configure.
export CC="${CUDA_PATH}/bin/gcc"
export CXX="${CUDA_PATH}/bin/g++"
export PYTEST_ADDOPTS="--disable-warnings"
export PYTHONPATH="$(pwd)/../install/usr/lib/python${PYVER}/site-packages"

# Run.
TMP_FILE=/tmp/$(uuidgen)

export PATH="${CUDA_PATH}/bin/:${PATH}"

set +e
python3 test/run_test.py -pt | tee $TMP_FILE
set -e

EXITCODE=0
if [ "$?" != "0" ] ; then
    EXITCODE=2
fi

# Count the various types of results.
echo -e '\n\n\n\n\n\n\n\n ================================================================\n'
for TYPE in pass skip fail error xpass xfail warning ; do
    eval "TOTAL_${!TYPE}=0"
    for N in $(grep -E "=+.* [0-9]+ ${TYPE}.*in [0-9.(): s]+=+" $TMP_FILE | sed -E "s/.* ([0-9]+) ${TYPE}.*/\1/") ; do
        eval "TOTAL_${!TYPE}=$(expr $TOTAL_${!TYPE} + $N)"
    done
    echo ${TYPE}: $TOTAL_${!TYPE}
done

# Done :)
rm $TMP_FILE
exit $EXITCODE
