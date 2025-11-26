#!/bin/bash

if [[ -z "$1" || -z "$2" ]]; then
    echo "Get a list of missing cuda names from the pytorch build diagnostics"
    echo "  usage: $(basename $0).sh <build log> <out file>"
fi

IN="$1"
OUT="$2"

rg "error: ‘([\w\d_]+)’ was not declared in this scope" -Nor '$1' $IN \
	| sort -u \
	| rg '^(cu|CU)' \
	| tee $OUT

