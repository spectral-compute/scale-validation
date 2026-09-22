#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone stdgpu https://github.com/stotko/stdgpu.git "$(get_version stdgpu)"
