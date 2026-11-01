#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Same as faiss/WarpSizeApi.patch.
(cd faiss && patch -p0 <"${SCRIPT_DIR}/faiss-WarpSizeApi.patch")
