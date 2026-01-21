#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

do_clone_hash stdgpu https://github.com/stotko/stdgpu.git "$(get_version stdgpu)"
