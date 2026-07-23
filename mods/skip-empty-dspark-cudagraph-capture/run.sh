#!/usr/bin/env bash
# Avoid entering DSpark's full-graph capture context when PIECEWISE has no candidates.
set -euo pipefail

readonly SITE_PACKAGES="$(python3 -c 'import site; print(site.getsitepackages()[0])')"
readonly SPECULATOR="${SITE_PACKAGES}/vllm/v1/worker/gpu/spec_decode/dflash/speculator.py"
readonly MARKER="skip-empty-dspark-cudagraph-capture"

SOURCE_FILE="${SPECULATOR}" PATCH_MARKER="${MARKER}" python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["SOURCE_FILE"])
marker = os.environ["PATCH_MARKER"]
text = path.read_text()
old = '''        assert self.query_cudagraph_manager is not None
        self.query_cudagraph_manager.capture(
'''
new = '''        assert self.query_cudagraph_manager is not None
        # skip-empty-dspark-cudagraph-capture: DSpark supports only FULL draft
        # graphs. An explicitly PIECEWISE target gives this manager no capture
        # candidates; entering the distributed graph context anyway can wedge
        # multi-node startup before the API becomes healthy.
        if not self.query_cudagraph_manager.needs_capture():
            logger.info(
                "Skipping %s speculator CUDA graph capture: no compatible candidates",
                self._speculator_name,
            )
            return
        self.query_cudagraph_manager.capture(
'''

if marker in text:
    print(f"[{marker}] already applied; skipping")
else:
    if text.count(old) != 1:
        raise RuntimeError("expected exactly one DFlash/DSpark capture call")
    path.write_text(text.replace(old, new, 1))
    print(f"[{marker}] applied to {path}")
PY

python3 -m py_compile "${SPECULATOR}"
grep -q "if not self.query_cudagraph_manager.needs_capture():" "${SPECULATOR}"
echo "[${MARKER}] compile and marker checks passed"
