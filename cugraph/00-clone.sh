#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone cugraph https://github.com/rapidsai/cugraph "$(get_version cugraph)"
