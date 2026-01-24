#!/bin/bash

set -ETeuo pipefail

cd llm.c
./train_gpt2fp32cu | tee output.log

# Check the output matches that obtained on the nvidia device.
cat << EOF > expected.log
generating:
---

I am pale and ill-smyth'd:
Quoth the poor rascal, 'twas now on
What should have been my way?'
I mean,
I must head home to New Hamporn as well as my own.

<|endoftext|>SAMUSIO:
If my luck outweighs
---
generating:
---
EditBOOK IX:
Under the boasted sute of Georges:
So lordly is the prize had sin is high;
Hell is the way to God: frankish friends from blessed daughters
To Bermuda have heard the saying,
Then how to place the artscape.
Strong should a bellow
---
EOF

cat output.log | sed -n '/generating:/,/step/p' | grep -v "step 40" | grep -v "step 20" > test.log
diff test.log expected.log
