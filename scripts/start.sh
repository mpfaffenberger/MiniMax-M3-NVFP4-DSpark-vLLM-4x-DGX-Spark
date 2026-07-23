#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

setup=0
if [[ "${1:-}" == "--setup" ]]; then
    setup=1
    shift
fi
[[ $# -eq 0 ]] || { echo "Usage: $0 [--setup]" >&2; exit 2; }

RUNTIME_DIR="${RUNTIME_DIR}" "${REPO_ROOT}/scripts/bootstrap.sh"
cp "${ENV_FILE}" "${RUNTIME_DIR}/.env"
args=(
    "${RUNTIME_DIR}/recipes/minimax-m3-nvidia-nvfp4-dspark.yaml"
    -n "${CLUSTER_NODES}"
    --name "${CONTAINER_NAME}"
    --no-ray
    --daemon
)
[[ ${setup} -eq 1 ]] && args+=(--setup)

cd "${RUNTIME_DIR}"
if [[ -n "${RECIPE_PYTHON:-}" ]]; then
    "${RECIPE_PYTHON}" ./run-recipe.py "${args[@]}"
elif python3 -c 'import yaml' 2>/dev/null; then
    python3 ./run-recipe.py "${args[@]}"
elif command -v uv >/dev/null 2>&1; then
    uv run --with pyyaml python ./run-recipe.py "${args[@]}"
else
    ./run-recipe.sh "${args[@]}"
fi
echo "Launch dispatched. Follow startup with: ./scripts/logs.sh -f"
