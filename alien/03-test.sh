#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

./build/EngineTests --gtest_filter=-DataTransferTests.largeData:MutationTests.insertMutation_emptyGenome
./build/NetworkTests
