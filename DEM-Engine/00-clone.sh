#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone DEM-Engine https://github.com/projectchrono/DEM-Engine.git "$(get_version DEM-Engine)"
