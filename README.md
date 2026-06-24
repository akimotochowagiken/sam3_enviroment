# SAM 3 検証用コンテナ（PyTorch + JupyterLab）on Portainer

社内サーバ（NVIDIA GPU / ドライバ導入済み）上に、SAM 3 を「VM的」に使える検証コンテナを立てる手順です。中に JupyterLab とシェルが入っているので、ブラウザや `docker exec` で入って自由に検証できます。

## 前提
- ホストに NVIDIA GPU + ドライバ導入済み（`nvidia-smi` が通る）
- Docker と Portainer が稼働中
- **NVIDIA Container Toolkit が必要**（DockerからGPUを使うための仕組み）。SAM 3 はGPU必須。

## 0. NVIDIA Container Toolkit の確認（重要）
ドライバとは別物です。未導入だとコンテナからGPUが見えません。ホストで確認:

```bash
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi
```

GPU情報が表示されればOK。エラーになる場合は Toolkit を導入してください（Ubuntu例）:

```bash
# NVIDIA公式リポジトリを追加して導入（バージョンは公式手順に合わせる）
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

## 1. イメージのビルド（ホスト側で一度だけ）
`Dockerfile` を置いたディレクトリで:

```bash
docker build -t sam3-dev:latest .
```

> flash-attn-3 を使う場合は Dockerfile 内の該当行のコメントを外してから再ビルド（ビルドに時間がかかります）。

## 1.5 SSH公開鍵を用意（VS Codeから入る場合）
手元のPC（Mac）で鍵が無ければ作成:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/sam3_dev -C "sam3-dev"
cat ~/.ssh/sam3_dev.pub   # ← この1行をまるごとコピー
```

この公開鍵の文字列を、手順3の `SSH_PUBKEY` に設定します。

## 2. Hugging Face トークンを用意
SAM 3 のチェックポイントは**ゲート付き**です。事前に:
1. https://huggingface.co/facebook/sam3 でアクセス申請して承認を受ける
2. https://huggingface.co/settings/tokens で read 権限のトークンを発行

## 3. Portainer でデプロイ
1. Portainer → 対象環境 → **Stacks** → **+ Add stack**
2. 名前を付け、`docker-compose.yml` の中身を Web editor に貼り付け
3. 画面下の **Environment variables** で以下を設定
   - `HF_TOKEN` … 発行したHuggingFaceトークン
   - `SSH_PUBKEY` … 手順1.5でコピーした公開鍵（`ssh-ed25519 AAAA... sam3-dev` の1行まるごと）
4. **Deploy the stack**

> 補足: `SSH_PUBKEY` に空白や `=` が含まれるため、Portainerの環境変数欄では値を**そのまま1行**で貼り付けてください（クォート不要）。

## VS Code から SSH 接続する
1. VS Code に拡張機能 **Remote - SSH**（Microsoft製）を入れる
2. 手元の `~/.ssh/config` に以下を追記（IPは社内サーバのアドレス）:

```sshconfig
Host sam3-dev
    HostName <サーバのIP>
    Port 2222
    User root
    IdentityFile ~/.ssh/sam3_dev
```

3. まず通常のターミナルで疎通確認:

```bash
ssh sam3-dev
```

4. VS Code → コマンドパレット（⌘⇧P）→ **Remote-SSH: Connect to Host** → `sam3-dev` を選択
5. 接続後、左下が「SSH: sam3-dev」になればOK。フォルダを開くで `/workspace` を選ぶと、その中で開発・デバッグできます。SAM3本体は `/opt/sam3` にあります。

> 初回接続時、VS Codeはリモート側（コンテナ内）にサーバコンポーネントを自動DLします（要インターネット）。Python拡張を入れれば `/opt/sam3` のサンプルもそのまま実行・デバッグ可能です。

### 代替案: SSH不要の「Dev Containers: Attach」
ホストのDockerに直接つなぐなら、拡張機能 **Dev Containers** を入れて
コマンドパレット → **Dev Containers: Attach to Running Container** → `sam3-dev` を選ぶ方法もあります。
鍵設定が不要で手軽ですが、VS Codeを動かすPCからホストのDockerにアクセスできる必要があります。SSH指定なら上の手順を使ってください。

> 補足: Portainer 上でDockerfileからビルドしたい場合は、build method を **Repository** にしてこの一式を置いたGitリポジトリを指定し、compose内の `build:` を有効化してください。社内にレジストリがあるなら「方法A（事前ビルド＋push）」が安定します。

## 4. アクセスと動作確認
- JupyterLab: ブラウザで `http://<サーバIP>:8888`
- シェルで入る: `docker exec -it sam3-dev bash`

GPUとSAM3の確認（`check_gpu.py` を /workspace に置いた場合）:

```bash
docker exec -it sam3-dev python /workspace/check_gpu.py
```

`CUDA available: True` とGPU名、`sam3 import: OK` が出れば環境は完成です。

## 5. チェックポイントの取得（コンテナ内）
```bash
# HFにログイン（環境変数 HF_TOKEN が入っていれば --token で渡せる）
huggingface-cli login --token "$HF_TOKEN"
# 例: モデルをローカルに取得（リポジトリ内の手順/notebookに従う）
huggingface-cli download facebook/sam3 --local-dir /workspace/checkpoints
```

実際のロード方法・推論コードは `/opt/sam3` のサンプルノートブック（`pip install -e ".[notebooks]"` 済み）を参照してください。

## メモ
- データやモデルは `/workspace`（名前付きボリューム `sam3_workspace`）に永続化されます。コンテナを作り直しても消えません。
- 特定GPUだけ使いたい場合は compose の `count: all` を `device_ids: ["0"]` 等に変更。
- JupyterLab はトークン無効化（社内ネット前提）。外部公開する場合は必ずトークン/パスワードを有効化してください。
# sam3_enviroment
# sam3_enviroment
# sam3_enviroment
