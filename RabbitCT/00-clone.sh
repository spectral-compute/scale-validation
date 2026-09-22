#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone RabbitCT https://github.com/spectral-compute/RabbitCT "$(get_version RabbitCT)"

# TODO: Find some way to cache this?
(cd RabbitCT && ./download-input.sh <<<"y")
