#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

./build/EngineTests --gtest_filter=-DataTransferTests.largeData:MutationTests.insertMutation_emptyGenome
./build/NetworkTests
