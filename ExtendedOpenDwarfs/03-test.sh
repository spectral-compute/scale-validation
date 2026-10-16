#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd ExtendedOpenDwarfs

# Should already be done in build, but it's idempotent anyway
. "$SCRIPT_DIR/tools/madness.sh"
./scripts/prepare_dataset.sh "$APP"

make run \
    APP="$APP" \
    BACKEND="$BACKEND" \
    COMPILER="$COMPILER" \
    SIZE="$SIZE" \
    ITERS="$ITERS" \
    DO_PLOTS=0
