#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone ScalingElections https://github.com/ashvardanian/ScalingElections.git "$(get_version ScalingElections)"
