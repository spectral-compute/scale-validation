#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone hashcat https://github.com/hashcat/hashcat.git "$(get_version hashcat)"
