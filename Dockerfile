FROM docker.io/spectralcompute/scale:latest

RUN apt update && \
    apt install -y apt-transport-https gnupg patch ninja-build gfortran curl python3 python3-pip python3-pytest python3-venv autoconf meson cargo
    
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    . /root/.local/bin/env bash && \
    uv tool install dvc[s3]

# bazel
RUN curl -fsSL https://releases.bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel-archive-keyring.gpg && \
    mv bazel-archive-keyring.gpg /usr/share/keyrings/ && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list && \
    apt update && \
    apt install -y bazel
