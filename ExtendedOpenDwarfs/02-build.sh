#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd ExtendedOpenDwarfs

. "${SCRIPT_DIR}/extra-vars.sh"

./scripts/prepare_dataset.sh "$APP"

make build \
    APP="$APP" \
    BACKEND="$BACKEND" \
    COMPILER="$COMPILER" \
    SIZE="$SIZE" \
    ITERS="$ITERS"
