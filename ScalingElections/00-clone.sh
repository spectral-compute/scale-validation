#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone_hash ScalingElections https://github.com/ashvardanian/ScalingElections.git "$(get_version ScalingElections)"
