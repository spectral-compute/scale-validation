#!/bin/bash

set -e

do_clone vllm https://github.com/vllm-project/vllm.git "$(get_version vllm)"
