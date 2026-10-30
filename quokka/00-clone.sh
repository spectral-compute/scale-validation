#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone quokka https://github.com/quokka-astro/quokka.git "$(get_version quokka)"
