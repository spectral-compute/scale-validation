#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# shellcheck disable=SC2164
cd "./build/test"

export LD_LIBRARY_PATH="${CUDA_PATH}/lib"
for F in $(find . -maxdepth 1 -type f -perm /u+x | grep -vE '\.so$' | sort); do
    echo -e "${F}"
    case "${F}" in
    ./l1_compact)
        log 'Crashes on Nvidia'
        ;;
    ./spv_cu)
        "${F}" || true
        log 'Broken on Nvidia'
        ;;
    *)
        "${F}"
        ;;
    esac
done

# shellcheck disable=SC2103,SC2164
cd -
