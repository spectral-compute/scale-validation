# LLama-CPP-Python

A Python binding for the llama.cpp library, enabling seamless integration of LLaMA models into Python applications.

Within this validation we showcase examples of what can be done using llama-cpp-python alongside SCALE.

This examples are shown in notebooks.

# Setting up Notebooks

To run the notebooks, you will need to install the required dependencies. You can do this by:

First sourcing your SCALE environment, and then your project virtual environment (created within `02-build.sh`). Eg:

```bash
source "${SCALE_DIR}/bin/scaleenv" gfx1100
source ${OUT_DIR}/llama-cpp-python/llama_cpp_python_scale_venv/bin/activate
```

Then installing the following packages:

```bash
pip install ipykernel
pip install jupyter-lab

python -m ipykernel install --user --name=my-project-venv --display-name="Python 3 (My Project)"

pip install matplotlib ipympl
```

# Running Notebooks

To run the notebooks, navigate to the `notebooks` directory and start Jupyter Lab:
`jupyter lab`

Note: if you are running on a remote server, you may need to set up SSH tunneling to access Jupyter Lab from your local
machine by:

Within remote server, run:
`jupyter lab --no-browser --port=8889`

Within local machine, run:
`ssh -N -L 8889:localhost:8889 user@remote-server-address`

## Activate the virtual environment within the notebook

Within the notebook, ensure you select the kernel corresponding to your virtual environment (e.g., "Python 3 (My
Project)") from the kernel selection menu, located in the top right corner of the Jupyter interface.
