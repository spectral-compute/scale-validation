# Third-party datasets

The prepared Level 6 files are transformed copies of the datasets below

Keep this file, `dataset_manifest.json` and the Fashion-MNIST licence notice when committing or redistributing the prepared data

This is a record of the licences and transformations used by this repository, not legal advice

## Breast Cancer Wisconsin (Diagnostic)

- **Creators:** William Wolberg, Olvi Mangasarian, Nick Street and W. Street
- **Publisher:** UCI Machine Learning Repository
- **Dataset page:** https://archive.ics.uci.edu/dataset/17/breast%2Bcancer%2Bwisconsin%2Bdiagnostic
- **DOI:** https://doi.org/10.24432/C5DW2B
- **Licence:** Creative Commons Attribution 4.0 International
- **Licence text:** https://creativecommons.org/licenses/by/4.0/

The prepared version removes the identifier column, maps the diagnosis to integer labels, creates a fixed stratified train/evaluation split, and standardises features using the training split statistics

Suggested citation:

> Wolberg, W., Mangasarian, O., Street, N., & Street, W. (1993). Breast Cancer Wisconsin (Diagnostic) [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5DW2B

## Fashion-MNIST

- **Creator:** Zalando Research / Zalando SE
- **Project page:** https://github.com/zalandoresearch/fashion-mnist
- **Licence:** MIT
- **Licence notice:** `datasets/licenses/FASHION_MNIST_LICENSE.txt`

The prepared version parses the original IDX files, selects fixed class-balanced train/evaluation subsets, converts images to `float32` values in `[0, 1]`, and applies no data augmentation

The original copyright and MIT permission notice must remain with redistributed copies or substantial portions

## SMS Spam Collection

- **Creators:** Tiago Almeida and Jos Hidalgo
- **Publisher:** UCI Machine Learning Repository
- **Dataset page:** https://archive.ics.uci.edu/dataset/228/sms%2Bspam%2Bcollection
- **DOI:** https://doi.org/10.24432/C5CC84
- **Licence:** Creative Commons Attribution 4.0 International
- **Licence text:** https://creativecommons.org/licenses/by/4.0/

The prepared version creates a fixed stratified train/evaluation split, normalises and tokenises the messages, builds the vocabulary from the training split only, and stores padded token IDs, masks and labels

Suggested citation:

> Almeida, T. & Hidalgo, J. (2011). SMS Spam Collection [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5CC84

The source contains real message text. The prepared repository files use token IDs and a generated vocabulary, but they are still derived from that text. Check the organisation's privacy and repository rules as well as the dataset licence before publishing them
