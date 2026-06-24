"""コンテナ内でGPUとSAM3が見えているか確認する簡易スクリプト。
使い方: docker exec -it sam3-dev python /workspace/check_gpu.py
"""
import torch

print("torch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("CUDA version (torch):", torch.version.cuda)
    print("GPU count:", torch.cuda.device_count())
    for i in range(torch.cuda.device_count()):
        print(f"  [{i}] {torch.cuda.get_device_name(i)}")
else:
    print("GPUが見えていません。NVIDIA Container Toolkit とGPU割り当てを確認してください。")

try:
    import sam3  # noqa: F401
    print("sam3 import: OK")
except Exception as e:
    print("sam3 import: NG ->", e)
