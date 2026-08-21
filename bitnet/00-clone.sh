#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone bitnet https://github.com/microsoft/BitNet.git "$(get_version bitnet)"
