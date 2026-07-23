#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-vllm-node-tf5-minimax-m3-dspark-20260722}"
readonly IMAGE

command -v docker >/dev/null || {
    echo "docker is required" >&2
    exit 1
}

docker image inspect "${IMAGE}" --format \
    'image={{.Id}} architecture={{.Os}}/{{.Architecture}} size={{.Size}}'

architecture="$(docker image inspect "${IMAGE}" --format '{{.Architecture}}')"
[[ "${architecture}" == "arm64" ]] || {
    echo "Expected arm64 image, got ${architecture}" >&2
    exit 1
}

docker run --rm --entrypoint bash "${IMAGE}" -lc '
set -euo pipefail
[[ ! -d /root/.cache/huggingface ]] || {
    echo "Image unexpectedly contains a Hugging Face cache" >&2
    exit 1
}
if find / -xdev -type f -size +2G -print -quit 2>/dev/null | grep -q .; then
    echo "Image unexpectedly contains a file larger than 2 GiB" >&2
    exit 1
fi
python3 - <<"PY"
import importlib.metadata
import vllm
expected_runtime = "0.23.1rc1.dev1388+gb44311b6e.d20260722"
expected_package = f"{expected_runtime}.cu132"
package = importlib.metadata.version("vllm")
if vllm.__version__ != expected_runtime or package != expected_package:
    raise SystemExit(
        f"unexpected vLLM versions: runtime={vllm.__version__}, package={package}"
    )
print(f"vLLM runtime={vllm.__version__} package={package}")
PY
cat /workspace/build-metadata.yaml
'

echo "Container audit passed."
