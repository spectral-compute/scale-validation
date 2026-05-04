#!/bin/bash

set -e

./build/EngineTests --gtest_filter=-DataTransferTests.largeData:MutationTests.insertMutation_emptyGenome
./build/NetworkTests
