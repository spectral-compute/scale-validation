#!/bin/bash
set -e

source "$(dirname "$0")"/../util/checks.sh

check_device_query() {
    local out
    out="$(../install/bin/caffe device_query -gpu 0 2>&1)"
    echo "${out}"
    echo "${out}" | grep -iE 'Device id|Total global memory'
}

check_help() {
    local out
    out="$(../install/bin/caffe --help 2>&1 || true)"
    echo "${out}"
    echo "${out}" | grep -iE 'command line brew|device_query|train'
}

check_no_cudnn() {
    local libs
    libs="$(ldd ../install/bin/caffe 2>&1 | grep -i cudnn || true)"
    echo "cudnn lines: '${libs}'"
    [ -z "${libs}" ]
}

check "device_query reports GPU"  check_device_query
check "--help lists subcommands"  check_help
check "no cuDNN linked (ldd)"     check_no_cudnn

check_exit
