#!/bin/bash

set -e

TEST_DIR="$(dirname "$0")"

USAGE_SUFFIX=" TEST [SKIP] [STOP_AFTER]"
PARTIAL_PARSE=1
source "${TEST_DIR}/util/args.sh" "$@"

# Process the script arguments with an array. This array will end up with just the arguments that should be passed to
# the child scripts.
ARGS=("$@")

function getOurArgument
{
    if [ "${#ARGS[@]}" == "0" ] ; then
        echo "${USAGE}" 1>&2
        exit 1
    fi
    echo "${ARGS[${#ARGS[@]}-1]}"
}

# Unconditionally get the first argument.
TEST="$(getOurArgument)"
unset ARGS[${#ARGS[@]}-1]

# If we got a number, shuffle the argument along, and get the next one.
if echo "${TEST}" | grep -qE '^[0-9]+$' ; then
    SKIP="${TEST}"
    TEST="$(getOurArgument)"
    unset ARGS[${#ARGS[@]}-1]
fi

# If we got a number, shuffle the argument along, and get the next one.
if echo "${TEST}" | grep -qE '^[0-9]+$' ; then
    STOP_AFTER="${SKIP}"
    SKIP="${TEST}"
    TEST="$(getOurArgument)"
    unset ARGS[${#ARGS[@]}-1]
fi

# The next argument should be a subdirectory of the directory this script is in.
if [ "$TEST" == "util" ] || [ ! -d "${TEST_DIR}/${TEST}" ] ; then
    echo "Unknown test: ${TEST}" 2>&1
    exit 1
fi

# If no skip was given (even 0), then delete the
if [ -z "${SKIP}" ] ; then
    rm -rf "${OUT_DIR}/${TEST}"
fi
mkdir -p "${OUT_DIR}/${TEST}"

# If no stop-after was given, then use the number of tests.
if [ -z "${STOP_AFTER}" ] ; then
    STOP_AFTER="$(find "${TEST_DIR}/${TEST}" -type f | wc -l)"
fi

# Run all the scripts for the test.
RETURN_CODE=0
I=0
for S in "${TEST_DIR}/${TEST}"/* ; do
    if [ ! -x "${S}" ] ; then
        continue
    fi

    J=$I
    I=$(expr $I + 1)
    if [ ! -z "${SKIP}" ] && [[ $J -lt ${SKIP} ]] ; then
        echo -e "Skipping \x1b[1m$(basename "$S")\x1b[0m in \x1b[1m${TEST}\x1b[0m"
        continue
    fi

    if [ ! -z "${STOP_AFTER}" ] && [[ $J -ge ${STOP_AFTER} ]] ; then
        echo -e "Skipping \x1b[1m$(basename "$S")\x1b[0m in \x1b[1m${TEST}\x1b[0m"
        continue
    fi

    echo -e "Running \x1b[1m$(basename "$S")\x1b[0m in \x1b[1m${TEST}\x1b[0m"

    set +e
    "$S" "${ARGS[@]}"
    R="$?"
    set -e

    if [ "$R" == "0" ] ; then
        continue
    elif [ "$R" == "222" ] ; then
        RETURN_CODE=222
    else
        exit "$R"
    fi
done

exit $RETURN_CODE
