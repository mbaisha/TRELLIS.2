# 基础镜像：conda+CUDA12.4+Python3.10（适配PyTorch cu124版本，内置conda无需额外安装）
FROM continuumio/miniconda3:latest

# 维护者信息（可选）
LABEL maintainer="trellis2-app"
LABEL description="Trellis2 with all extensions enabled (CUDA platform)"

# 设置环境变量：固定CUDA平台、避免pip缓存、conda自动激活环境
ENV PLATFORM=cuda
ENV PIP_NO_CACHE_DIR=1
ENV CONDA_AUTO_ACTIVATE_BASE=false
ENV APP_HOME=/app

# 创建工作目录并设置为默认
WORKDIR ${APP_HOME}

# 1. 创建并激活conda环境trellis2，安装PyTorch 2.6.0+torchvision 0.21.0（CUDA12.4版本）
RUN conda create -n trellis2 python=3.10 -y && \
    echo "conda activate trellis2" >> ~/.bashrc && \
    /bin/bash -c "source ~/.bashrc && \
    pip install torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cu124"

# 2. 安装--basic依赖（含系统依赖libjpeg-dev、第三方git库、pillow-simd等）
RUN /bin/bash -c "source ~/.bashrc && \
    apt-get update && apt-get install -y --no-install-recommends libjpeg-dev git gcc && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    pip install imageio imageio-ffmpeg tqdm easydict opencv-python-headless ninja trimesh transformers gradio==6.0.1 tensorboard pandas lpips zstandard && \
    pip install git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8 && \
    pip install pillow-simd kornia timm"

# 3. 安装--flash-attn（CUDA平台直接安装预编译包2.7.3）
RUN /bin/bash -c "source ~/.bashrc && \
    pip install flash-attn==2.7.3"

# 4. 安装--nvdiffrast（CUDA平台，克隆v0.4.0版本并本地安装）
RUN /bin/bash -c "source ~/.bashrc && \
    mkdir -p /tmp/extensions && \
    git clone -b v0.4.0 https://github.com/NVlabs/nvdiffrast.git /tmp/extensions/nvdiffrast && \
    pip install /tmp/extensions/nvdiffrast --no-build-isolation && \
    rm -rf /tmp/extensions/nvdiffrast"

# 5. 安装--nvdiffrec（CUDA平台，克隆renderutils分支并本地安装）
RUN /bin/bash -c "source ~/.bashrc && \
    mkdir -p /tmp/extensions && \
    git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git /tmp/extensions/nvdiffrec && \
    pip install /tmp/extensions/nvdiffrec --no-build-isolation && \
    rm -rf /tmp/extensions/nvdiffrec"

# 6. 安装--cumesh（递归克隆仓库并本地安装）
RUN /bin/bash -c "source ~/.bashrc && \
    mkdir -p /tmp/extensions && \
    git clone https://github.com/JeffreyXiang/CuMesh.git /tmp/extensions/CuMesh --recursive && \
    pip install /tmp/extensions/CuMesh --no-build-isolation && \
    rm -rf /tmp/extensions/CuMesh"

# 7. 安装--flexgemm（递归克隆仓库并本地安装）
RUN /bin/bash -c "source ~/.bashrc && \
    mkdir -p /tmp/extensions && \
    git clone https://github.com/JeffreyXiang/FlexGEMM.git /tmp/extensions/FlexGEMM --recursive && \
    pip install /tmp/extensions/FlexGEMM --no-build-isolation && \
    rm -rf /tmp/extensions/FlexGEMM"

# 8. 拷贝当前目录所有文件到工作目录（先拷贝，保证o-voxel目录存在）
COPY . ${APP_HOME}

# 9. 安装--o-voxel（基于拷贝的本地o-voxel目录，本地安装）
RUN /bin/bash -c "source ~/.bashrc && \
    mkdir -p /tmp/extensions && \
    cp -r ${APP_HOME}/o-voxel /tmp/extensions/o-voxel && \
    pip install /tmp/extensions/o-voxel --no-build-isolation && \
    rm -rf /tmp/extensions/o-voxel /tmp/extensions"

# 暴露端口（若app.py使用Gradio/Flask等网络服务，可根据实际修改端口，默认留8000）
EXPOSE 7860

# 启动命令：激活conda环境并运行python app.py
CMD ["/bin/bash", "-c", "source ~/.bashrc && python app.py"]
