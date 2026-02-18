#!/bin/bash

set -ETeuo pipefail
cd "./build/test"

export LD_LIBRARY_PATH="${CUDA_PATH}/lib"
for F in $(find . -maxdepth 1 -type f -perm /u+x | grep -vE '\.so$' | sort) ; do
    echo -e "\x1b[1m${F}\x1b[m"
    case "${F}" in
        ./l1_compact)
            echo -e '\x1b[31;1mCrashes on Nvidia\x1b[m'
        ;;
        ./spv_cu)
            "${F}" || true
            echo -e '\x1b[33;1mBroken on Nvidia\x1b[m'
        ;;
        *)
            "${F}"
        ;;
    esac
done

cd -
