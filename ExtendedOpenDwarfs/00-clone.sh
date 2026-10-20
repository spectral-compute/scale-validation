#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone ExtendedOpenDwarfs https://github.com/ANU-HPC/ExtendedOpenDwarfs.git "$(get_version ExtendedOpenDwarfs)"
