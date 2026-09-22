#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

(
    cd RabbitCT &&
        ./rabbitRunner-NVCC \
            -i ./RabbitInput/RabbitInput.rct \
            -m LolaCUDA \
            -s 1024 \
            -c ./RabbitInput/Reference1024.vol

)
