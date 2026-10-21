#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone openfold-3 https://github.com/aqlaboratory/openfold-3.git "$(get_version openfold3)"
