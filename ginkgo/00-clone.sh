#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone ginkgo https://github.com/ginkgo-project/ginkgo.git "$(get_version ginkgo)"
