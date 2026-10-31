#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone ppisp https://github.com/nv-tlabs/ppisp.git "$(get_version ppisp)"
