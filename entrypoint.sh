#!/usr/bin/env bash
set -e

# --- SSH 公開鍵をセット（環境変数 SSH_PUBKEY 経由） ---
mkdir -p /root/.ssh
chmod 700 /root/.ssh
if [ -n "${SSH_PUBKEY}" ]; then
    echo "${SSH_PUBKEY}" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "[entrypoint] authorized_keys を設定しました。"
else
    echo "[entrypoint] 警告: SSH_PUBKEY が未設定です。SSHログインできません。"
fi

# ホスト鍵を生成（無ければ）してsshd起動
ssh-keygen -A
/usr/sbin/sshd
echo "[entrypoint] sshd を起動しました (port 22)。"

# --- JupyterLab（任意。ENABLE_JUPYTER=0 で無効化） ---
if [ "${ENABLE_JUPYTER:-1}" = "1" ]; then
    jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
        --ServerApp.token="" --ServerApp.password="" \
        --notebook-dir=/workspace &
    echo "[entrypoint] JupyterLab を起動しました (port 8888)。"
fi

# コンテナを常駐させる
tail -f /dev/null
