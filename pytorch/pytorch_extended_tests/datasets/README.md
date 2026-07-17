# Datasets for `pytorch_extended_tests`

This directory contains the fixed inputs used by the extended tests.

CI and normal test runs use only `datasets/prepared/` and `dataset_manifest.json`. The source archives under `datasets/downloaded/` are needed only while creating or deliberately regenerating the Level 6 prepared data. After a successful full preparation, the downloaded archives can be deleted.

The CI jobs shouldn't download or regenerate data. (though we should move the prepared data out of this repo and to some CI-readable folder)

## Directory layout

```text
datasets/
├── generate_datasets.py
├── dataset_manifest.json
├── THIRD_PARTY_DATASETS.md
├── licenses/
│   └── FASHION_MNIST_LICENSE.txt
├── downloaded/                         # temporary source files, not required by CI
│   ├── breast_cancer_wisconsin/
│   ├── fashion_mnist/
│   └── sms_spam_collection/
└── prepared/
    ├── numerical_inputs_v1/
    ├── model_inputs_v1/
    ├── breast_cancer_wisconsin_v1/
    ├── fashion_mnist_v1/
    └── sms_spam_v1/
```

`prepared/` contains deterministic NumPy files used directly by the tests. The generator writes deterministic `.npz` archives, so running it again with the same source files, configuration and NumPy behaviour should produce the same file hashes

`model_inputs_v1/` includes the fixed batches and initial states for the Level 0 linear, MLP, CNN and attention examples as well as the Level 6 Transformer state

## Required suite configuration

The generator reads the seed and generation choices from the root-relative `config/suite_config.py` file. It expects at least the following values:

```python
SUITE_VERSION = "v1"
ROOT_SEED = 42

DATASET_GENERATION = {
    "breast_cancer_wisconsin": {
        "evaluation_fraction": 0.2,
    },
    "fashion_mnist": {
        "training_samples": 4096,
        "evaluation_samples": 1024,
    },
    "sms_spam": {
        "evaluation_fraction": 0.2,
        "max_sequence_length": 64,
        "max_vocabulary_size": 4096,
        "minimum_token_frequency": 1,
    },
    "numerical_inputs": {
        "vector_length": 257,
        "reduction_rows": 127,
        "reduction_columns": 61,
        "matrix_m": 127,
        "matrix_k": 61,
        "matrix_n": 89,
        "matrix_batch_size": 3,
    },
    "model_inputs": {
        "batch_size": 32,
        "linear_input_features": 30,
        "linear_output_features": 2,
        "mlp_input_features": 30,
        "mlp_hidden_features": [32, 16],
        "mlp_output_features": 2,
        "cnn_channels": [1, 8, 16],
        "cnn_classes": 10,
        "attention_sequence_length": 16,
        "attention_embedding_size": 32,
        "attention_heads": 4,
        "transformer_feedforward_size": 64,
        "transformer_layers": 2,
    },
}
```

These values live in `suite_config.py`. Do not add a separate seed to the generator

## Downloaded datasets

### Breast Cancer Wisconsin (Diagnostic)

This is used for the tabular classification workload

- Dataset page: <https://archive.ics.uci.edu/dataset/17/breast%2Bcancer%2Bwisconsin%2Bdiagnostic>
- Direct download: <https://archive.ics.uci.edu/static/public/17/breast%2Bcancer%2Bwisconsin%2Bdiagnostic.zip>
- DOI: <https://doi.org/10.24432/C5DW2B>
- Licence: Creative Commons Attribution 4.0

Save the downloaded archive as:

```text
datasets/downloaded/breast_cancer_wisconsin/breast_cancer_wisconsin_diagnostic.zip
```

### Fashion-MNIST

This is used for the image classification workload

- Project page: <https://github.com/zalandoresearch/fashion-mnist>
- Licence: MIT

Download these four official files:

- <https://fashion-mnist.s3-website.eu-central-1.amazonaws.com/train-images-idx3-ubyte.gz>
- <https://fashion-mnist.s3-website.eu-central-1.amazonaws.com/train-labels-idx1-ubyte.gz>
- <https://fashion-mnist.s3-website.eu-central-1.amazonaws.com/t10k-images-idx3-ubyte.gz>
- <https://fashion-mnist.s3-website.eu-central-1.amazonaws.com/t10k-labels-idx1-ubyte.gz>

Save them without renaming under:

```text
datasets/downloaded/fashion_mnist/
```

### SMS Spam Collection

This is used for the small Transformer workload

- Dataset page: <https://archive.ics.uci.edu/dataset/228/sms%2Bspam%2Bcollection>
- Direct download: <https://archive.ics.uci.edu/static/public/228/sms%2Bspam%2Bcollection.zip>
- DOI: <https://doi.org/10.24432/C5CC84>
- Licence: Creative Commons Attribution 4.0

Save the downloaded archive as:

```text
datasets/downloaded/sms_spam_collection/sms_spam_collection.zip
```

## Preparing Levels 0–5 only

No external downloads are needed:

```bash
python datasets/generate_datasets.py --only generated --force
```

This creates the final prepared numerical/model inputs used directly by Levels 0–5

## Preparing Level 6

1. Download the three sources into the paths above
2. Run the complete generator while those files are present:

```bash
python datasets/generate_datasets.py --force
```

3. Check that these directories and the manifest were updated:

```text
datasets/prepared/breast_cancer_wisconsin_v1/
datasets/prepared/fashion_mnist_v1/
datasets/prepared/sms_spam_v1/
datasets/dataset_manifest.json
```

4. Commit the prepared directories, manifest and third-party notices
5. Delete `datasets/downloaded/` contents if they should not be committed

Normal Level 6 execution validates the prepared files against the manifest and does not require the downloaded archives

To deliberately check the source archives as well, run:

```bash
python tools/validate_setup.py \
    --levels level_6_real_workloads \
    --profiles controlled_fp32
```

with `EXECUTION["validate_downloaded_sources"]` temporarily enabled, or call the validation API with source checking enabled

## Regenerating generated inputs after deleting downloads

This remains safe:

```bash
python datasets/generate_datasets.py --only generated --force
```

The generator preserves the recorded Level 6 source provenance in the manifest when those source archives are absent and were not selected for regeneration

Do not run the full generator after deleting the downloads. Full Level 6 regeneration needs the source files again

## Manifest behaviour

`dataset_manifest.json` records:

- the configured root seed and suite version
- source URLs, licences and source hashes recorded during preparation
- SHA-256 hashes and sizes for every prepared file
- the generation timestamp

The timestamp is informational and is not used to generate values

## Dependencies

The generator deliberately has a small dependency surface:

- Python 3.10 or newer
- NumPy

It does not require PyTorch, pandas, scikit-learn, torchvision or a Kaggle client

## Attribution and repository use

See [`THIRD_PARTY_DATASETS.md`](THIRD_PARTY_DATASETS.md) for the attribution, licence links, transformation notes and the SMS privacy warning

The UCI datasets are listed as CC BY 4.0 and Fashion-MNIST is MIT licensed. Keep the notices with redistributed prepared data and check the organisation's policies before publishing third-party data
