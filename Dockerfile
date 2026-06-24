# SAM 3 検証用 開発コンテナ
# ベース: PyTorch 2.7 / CUDA 12.6 / cuDNN9 (devel: nvcc同梱でflash-attn等のビルド可)
FROM pytorch/pytorch:2.7.0-cuda12.6-cudnn9-devel

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/workspace/.cache/huggingface \
    PYTHONUNBUFFERED=1

# OSパッケージ（git, ビルド系, SSHサーバ, 編集/確認系）
RUN apt-get update && apt-get install -y --no-install-recommends \
        git wget curl ca-certificates build-essential ninja-build \
        vim less tmux openssh-server openssh-client \
    && rm -rf /var/lib/apt/lists/*

# sshd 設定（鍵認証のみ・パスワードログイン無効）
RUN mkdir -p /var/run/sshd \
    && sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -i 's/#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

WORKDIR /workspace

# SAM 3 本体を取得してインストール
# （チェックポイントはゲート付きのため、実行時にHFトークンでDLする）
RUN git clone https://github.com/facebookresearch/sam3.git /opt/sam3 \
    && cd /opt/sam3 \
    && pip install --upgrade pip \
    && pip install -e ".[notebooks]" \
    && pip install einops

# 開発・検証用ツール（JupyterLab で「中に入って」使う）
RUN pip install jupyterlab huggingface_hub[cli] ipywidgets matplotlib opencv-python-headless

# flash-attn-3 は任意・ビルドが重い。必要なら下のコメントを外す
# RUN pip install flash-attn --no-build-isolation

# 起動スクリプト（sshd と JupyterLab を起動）
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22 8888

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
