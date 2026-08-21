#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone stdgpu https://github.com/stotko/stdgpu.git "$(get_version stdgpu)"
