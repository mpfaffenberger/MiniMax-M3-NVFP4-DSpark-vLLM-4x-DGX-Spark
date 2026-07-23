#!/bin/bash
set -euo pipefail
# fix-nccl-2.30.4: overwrite the image's bundled libnccl.so.2 (2.29.7) with 2.30.4
# on EVERY node's container. Mods run on all ranks; the recipe-env LD_PRELOAD only
# reaches the HEAD (ray workers start without the recipe env), so workers kept loading
# 2.29.7. 2.30.4 fixes the shm_broadcast wedge-under-load (2.29.7 is the documented bad
# version on GB10). Lib must be pre-staged at each node's ~/.cache/huggingface/hub/nccl-2.30.4/.
SRC="/root/.cache/huggingface/hub/nccl-2.30.4/libnccl.so.2"
DST="/usr/lib/aarch64-linux-gnu/libnccl.so.2"
[ -f "$SRC" ] || { echo "[fix-nccl-2.30.4] ERROR: $SRC missing on this node"; exit 1; }
if strings "$DST" 2>/dev/null | grep -q "2\.30\.4"; then echo "[fix-nccl-2.30.4] already 2.30.4"; exit 0; fi
cp -f "$SRC" "$DST"
echo "[fix-nccl-2.30.4] $DST -> $(strings "$DST" | grep -m1 '2\.30\.4')"
