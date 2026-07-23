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
python3 - <<'PY' "${ROOT}/recipes/minimax-m3-nvidia-nvfp4-dspark.yaml"
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
required = (
    '--distributed-executor-backend ray',
    '"method":"dspark"',
    '--reasoning-parser minimax_m3',
    '--tool-call-parser minimax_m3',
    '--kv-cache-dtype fp8',
)
missing = [marker for marker in required if marker not in text]
if missing:
    raise SystemExit(f"recipe is missing: {missing}")
PY

expected="cfda01f2ba3ebdb4b7970c0b140be8874eba5f43087682424e50e141fd51df78"
echo "${expected}  ${ROOT}/mods/install-vllm-rust-tool-parser/_rust_tool_parser.abi3.so" | sha256sum --check
[[ ${fail} -eq 0 ]] || exit 1
echo "Static validation passed."
