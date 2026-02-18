#!/usr/bin/env bash

source "$(dirname "$0")"/../util/git.sh

do_clone HeCBench https://github.com/zjin-lcf/HeCBench "$(get_version HeCBench)"

ERR_TEXT="This repository exceeded its LFS budget."

if (($? != 0)) && ! grep "$ERR_TEXT" HeCBench/.git/lfs/logs/* &>/dev/null; then
    exit 1
fi

# TODO: This doesn't seem to get unzipped during cmake configuration like
# everything else. Perhaps we can send them a patch. Their cmake build system is
# listed as experimental in the github, so is likely somewhat wip, but it is
# what was in the instructions Ruben got for building...
(
    cd HeCBench/src/slu-cuda/src
    tar -xvf nicslu.tar.bz2
)
