import os.path
import shutil
import sys
import tensorflow_datasets as tfds

# Usage: DownloadDataset.py OutputDirectory DatasetName

dataset = tfds.builder(sys.argv[2], data_dir=sys.argv[1])
dataset.download_and_prepare()

# The downloads directory contains intermediate files that aren't useful.
download_dir = os.path.join(sys.argv[1], 'downloads')
if os.path.exists(download_dir):
    shutil.rmtree(download_dir)
