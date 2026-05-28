#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash heraclespp https://github.com/Maison-de-la-Simulation/heraclespp.git "$(get_version heraclespp)"
