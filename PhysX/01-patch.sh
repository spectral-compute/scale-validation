#!/bin/bash

set -e

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

git -C PhysX apply "${SCRIPT_DIR}/scale-physx.patch"
