#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

git -C PhysX apply "${SCRIPT_DIR}/scale-physx.patch"
