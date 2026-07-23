#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT

fail=0
for script in "${ROOT}"/scripts/*.sh "${ROOT}"/mods/*/run.sh; do
    if ! bash -n "${script}"; then
        fail=1
    fi
done

python3 -m py_compile "${ROOT}/scripts/metrics.py" "${ROOT}/scripts/smoke.py"
python3 - <<'PY' \
    "${ROOT}/recipes/minimax-m3-nvidia-nvfp4-dspark.yaml" \
    "${ROOT}/submission/recipe.yaml" \
    "${ROOT}/container/image.env"
import sys
from pathlib import Path

production = Path(sys.argv[1]).read_text()
submission = Path(sys.argv[2]).read_text()
image_env = Path(sys.argv[3]).read_text()
image_ref = next(
    line.removeprefix("IMAGE_REF=")
    for line in image_env.splitlines()
    if line.startswith("IMAGE_REF=")
)
common = (
    '"method":"dspark"',
    '--reasoning-parser minimax_m3',
    '--tool-call-parser minimax_m3',
    '--kv-cache-dtype fp8',
    '--enforce-eager',
    'tensor_parallel: 4',
    'max_model_len: 262144',
)
for name, text in (("production", production), ("submission", submission)):
    missing = [marker for marker in common if marker not in text]
    if missing:
        raise SystemExit(f"{name} recipe is missing: {missing}")

if "/root/.cache/huggingface/" not in production:
    raise SystemExit("production recipe must retain direct local cache paths")
submission_required = (
    f"container: {image_ref}",
    "target_model: nvidia/MiniMax-M3-NVFP4",
    "target_revision: 901464083161bf8612a29ff7ad29914cd4ab4a85",
    "draft_model: nvidia/MiniMax-M3-DSpark",
    "draft_revision: e82db0e1895bc4e0c339ce670b2b553899a57f59",
    "--revision {target_revision}",
    '"revision":"{draft_revision}"',
)
missing = [marker for marker in submission_required if marker not in submission]
if missing:
    raise SystemExit(f"submission recipe is missing portable pins: {missing}")
if "/root/.cache/huggingface/" in submission:
    raise SystemExit("submission recipe contains a machine-specific cache path")
if "HF_HUB_OFFLINE" in submission or "TRANSFORMERS_OFFLINE" in submission:
    raise SystemExit("submission recipe unexpectedly forces offline mode")
PY

dockerfile_sha="2cb5a1fd72e515d1fdf5bcee31abe3b02816c45829c421b6d015a88a9b106c48"
flashinfer_patch_sha="142c2e8713ede936c70cd0bcaa1b074e616d06078926faebc2cdd2eb981c94be"
build_metadata_sha="97c82981f54815d77a3cba6edf659f4bade5f21218e1e46f5f15f3608d9dfa6b"
echo "${dockerfile_sha}  ${ROOT}/container/Dockerfile" | sha256sum --check
echo "${flashinfer_patch_sha}  ${ROOT}/container/flashinfer_cache.patch" | sha256sum --check
echo "${build_metadata_sha}  ${ROOT}/container/build-metadata.yaml" | sha256sum --check

results_sha="0dc298fc7c57ca5de91ee066fa1155b14746b53f33cca4c39c139eabc7c511ed"
echo "${results_sha}  ${ROOT}/results.csv" | sha256sum --check

expected="cfda01f2ba3ebdb4b7970c0b140be8874eba5f43087682424e50e141fd51df78"
echo "${expected}  ${ROOT}/mods/install-vllm-rust-tool-parser/_rust_tool_parser.abi3.so" | sha256sum --check
[[ ${fail} -eq 0 ]] || exit 1
echo "Static validation passed."
