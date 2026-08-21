#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone hashcat https://github.com/hashcat/hashcat.git "$(get_version hashcat)"
