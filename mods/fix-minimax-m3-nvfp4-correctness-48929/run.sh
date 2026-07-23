#!/usr/bin/env bash
# Apply vLLM PR #48929's MiniMax-M3 NVFP4 correctness fixes.
set -euo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${MOD_DIR}/pr48929-runtime.diff"
SITE_PACKAGES="${SITE_PACKAGES:-/usr/local/lib/python3.12/dist-packages}"
PATCH_LOG="$(mktemp)"
trap 'rm -f "${PATCH_LOG}"' EXIT

cd "${SITE_PACKAGES}"

if patch --forward -p1 --batch --dry-run < "${PATCH_FILE}" >"${PATCH_LOG}" 2>&1; then
    patch --forward -p1 --batch < "${PATCH_FILE}"
elif patch --forward -R -p1 --batch --dry-run < "${PATCH_FILE}" >"${PATCH_LOG}" 2>&1; then
    echo "[fix-minimax-m3-nvfp4-correctness-48929] already applied; skipping"
else
    echo "[fix-minimax-m3-nvfp4-correctness-48929] patch does not match this image" >&2
    cat "${PATCH_LOG}" >&2
    exit 1
fi

python3 - <<'PY'
from pathlib import Path
import py_compile

root = Path("/usr/local/lib/python3.12/dist-packages/vllm")
files = (
    "model_executor/layers/fused_moe/experts/flashinfer_cutlass_moe.py",
    "model_executor/layers/fused_moe/experts/marlin_moe.py",
    "model_executor/layers/quantization/utils/flashinfer_utils.py",
    "models/minimax_m3/common/indexer.py",
    "models/minimax_m3/common/sparse_attention.py",
    "models/minimax_m3/nvidia/indexer_msa.py",
    "models/minimax_m3/nvidia/model.py",
    "models/minimax_m3/nvidia/sparse_attention_msa.py",
)
for relative in files:
    path = root / relative
    py_compile.compile(str(path), doraise=True)

indexer = (root / "models/minimax_m3/common/indexer.py").read_text()
moe = (root / "model_executor/layers/fused_moe/experts/flashinfer_cutlass_moe.py").read_text()
assert "as_head_major_topk_indices" in indexer
assert "gemm1_alpha = _per_expert" in moe
assert "gemm1_beta = _per_expert" in moe
print("[fix-minimax-m3-nvfp4-correctness-48929] compile and marker checks passed")
PY
