#!/usr/bin/env bash
# Refuse to construct MiniMax-M3 MoE experts unless a ModelOpt NVFP4 format is active.
set -euo pipefail

MODEL_FILE="/usr/local/lib/python3.12/dist-packages/vllm/models/minimax_m3/nvidia/model.py"

MODEL_FILE="${MODEL_FILE}" python3 - <<'PY'
import os
from pathlib import Path
import py_compile

path = Path(os.environ["MODEL_FILE"])
text = path.read_text()
marker = "guard-minimax-m3-modelopt-fp4"
if marker in text:
    print(f"[{marker}] already applied; skipping")
else:
    class_at = text.index("class MiniMaxM3MoE(nn.Module):")
    init_at = text.index("        super().__init__()\n", class_at)
    insertion_at = init_at + len("        super().__init__()\n")
    guard = '''        # guard-minimax-m3-modelopt-fp4: never silently allocate BF16 experts.
        resolved = None if quant_config is None else quant_config.get_name()
        if resolved not in {"modelopt_fp4", "modelopt_mixed"}:
            raise RuntimeError(
                "Refusing to construct MiniMax-M3 MoE without a supported "
                f"ModelOpt NVFP4 format; resolved quantization={resolved!r}"
            )
'''
    text = text[:insertion_at] + guard + text[insertion_at:]
    path.write_text(text)
    print(f"[{marker}] applied")

py_compile.compile(str(path), doraise=True)
updated = path.read_text()
assert marker in updated
assert 'resolved not in {"modelopt_fp4", "modelopt_mixed"}' in updated
assert "resolved quantization={resolved!r}" in updated
print(f"[{marker}] compile and marker checks passed")
PY
