#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

(cd ds4 && make cuda-generic && ./download_model.sh q2-imatrix)
