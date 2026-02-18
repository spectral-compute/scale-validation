#!/bin/bash

set -e

ctest --test-dir build --output-on-failure --output-junit faiss.xml -E "MEM_LEAK.ivfflat"
