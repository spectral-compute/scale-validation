#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd ExtendedOpenDwarfs

# TODO: Why do we do this here and not in test.sh?
. "$SCRIPT_DIR/tools/madness.sh"
./scripts/prepare_dataset.sh "$APP"

make build \
    APP="$APP" \
    BACKEND="$BACKEND" \
    COMPILER="$COMPILER" \
    SIZE="$SIZE" \
    ITERS="$ITERS"
