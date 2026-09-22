#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone_hash ScalingElections https://github.com/ashvardanian/ScalingElections.git "$(get_version ScalingElections)"
