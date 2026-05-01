#!/usr/bin/env bash

source "$(dirname "$0")"/../util/git.sh

do_clone ColossalAI https://github.com/hpcaitech/ColossalAI.git "$(get_version ColossalAI)"
