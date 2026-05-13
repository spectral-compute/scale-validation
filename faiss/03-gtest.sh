#!/bin/bash

set -e

ctest --test-dir build --verbose --output-junit faiss.xml -E "MEM_LEAK.ivfflat"
