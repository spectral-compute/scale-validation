### Validated with  rocm6.4.1 docker from https://hub.docker.com/u/rocm

```bash

docker run -it --rm --network=host \
    --device=/dev/kfd --device=/dev/dri \
    --ipc=host --shm-size 16G \
    --group-add video \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    -v /home/workspace:/workspace \
   rocm/vllm:rocm6.4.1_vllm_0.9.1_20250702

```

### insider rocm docker, set up scale repo and install scale

```bash
cd /workspace

# Tell apt to authenticate to the repo
sudo tee /etc/apt/auth.conf.d/scale.conf <<EOF
machine unstable-nonfree-pkgs.scale-lang.com
login $CUSTOMER_NAME
password $CUSTOMER_PASSWORD
EOF
sudo chmod 700 /etc/apt/auth.conf.d/scale.conf
# Add the scale deb repos.

cd ~/workspace
wget --http-user="$CUSTOMER_NAME" --http-password="$CUSTOMER_PASSWORD" https://unstable-nonfree-pkgs.scale-lang.com/$CUSTOMER_NAME/deb/dists/jammy/main/binary-all/scale-repos.deb

sudo apt update
wget https://repo.radeon.com/amdgpu-install/6.4.1/ubuntu/jammy/amdgpu-install_6.4.60401-1_all.deb
sudo apt install ./amdgpu-install_6.4.60401-1_all.deb -y
sudo apt update

sudo apt install ./scale-repos.deb -y

# Install SCALE
sudo apt update && sudo apt install scale-unstable -y

# Add your user to the `video` group:
sudo usermod -a -G video $(whoami)
```

### get AMD GPU gfxID by scaleinfo
```bash
/opt/scale/bin/scaleinfo | grep gfx
```

### build rocm compatible cutlass_profiler
```bash
source /opt/scale/bin/scaleenv gfxXXX

cd /workspace
git clone https://github.com/spectral-compute/scale-validation.git
cd /workspace/scale-validation/cutlass

bash ./00-clone.sh ./ /opt/scale gfxXXX
bash ./01-patch.sh ./ /opt/scale gfxXXX
bash ./02-build.sh ./ /opt/scale gfxXXX

# rocm compatible cutlass_profiler in /workspace/scale-validation/cutlass/cutlass/build/tools/profiler folder
```


### Run cutlass_profiler on AMD GPU
```bash

cd /workspace/scale-validation/cutlass/cutlass/build/tools/profiler 
./cutlass_profiler --operation=Gemm --m=1024 --n=1024 --k=128 --output=functional-gemm-test.csv


```
