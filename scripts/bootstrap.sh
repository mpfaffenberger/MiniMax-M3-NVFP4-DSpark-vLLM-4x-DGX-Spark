#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
readonly UPSTREAM_URL="https://github.com/eugr/spark-vllm-docker.git"
readonly UPSTREAM_COMMIT="08c34dd8262e5b429a8cbf36bcf15507628c2999"
RUNTIME_DIR="${RUNTIME_DIR:-${ROOT}/.runtime/spark-vllm-docker}"

for command in git python3; do
    command -v "${command}" >/dev/null || {
        echo "Missing required command: ${command}" >&2
        exit 1
    }
done

if [[ ! -d "${RUNTIME_DIR}/.git" ]]; then
    mkdir -p "$(dirname "${RUNTIME_DIR}")"
    git clone "${UPSTREAM_URL}" "${RUNTIME_DIR}"
fi

current="$(git -C "${RUNTIME_DIR}" rev-parse HEAD)"
if [[ "${current}" != "${UPSTREAM_COMMIT}" ]]; then
    if [[ -n "$(git -C "${RUNTIME_DIR}" status --porcelain)" ]]; then
        echo "Runtime is dirty at ${current}; refusing to overwrite local work." >&2
        exit 1
    fi
    git -C "${RUNTIME_DIR}" cat-file -e "${UPSTREAM_COMMIT}^{commit}" 2>/dev/null || \
        git -C "${RUNTIME_DIR}" fetch origin "${UPSTREAM_COMMIT}"
    git -C "${RUNTIME_DIR}" checkout --detach "${UPSTREAM_COMMIT}"
fi

patch_file="${ROOT}/patches/spark-vllm-docker.patch"
if git -C "${RUNTIME_DIR}" apply --check "${patch_file}" 2>/dev/null; then
    git -C "${RUNTIME_DIR}" apply "${patch_file}"
elif git -C "${RUNTIME_DIR}" apply --reverse --check "${patch_file}" 2>/dev/null; then
    echo "Base runtime patch already applied."
else
    echo "Runtime patch is neither applicable nor already applied." >&2
    exit 1
fi

recipe="minimax-m3-nvidia-nvfp4-dspark.yaml"
cp "${ROOT}/recipes/${recipe}" "${RUNTIME_DIR}/recipes/${recipe}"
for mod in "${ROOT}"/mods/*; do
    [[ -d "${mod}" ]] || continue
    rm -rf "${RUNTIME_DIR}/mods/$(basename "${mod}")"
    cp -a "${mod}" "${RUNTIME_DIR}/mods/"
done

expected="4c00bb276904de5a12d27b70eff97250eca54716559e06b042f17b6cc827e944"
actual="$(sha256sum "${RUNTIME_DIR}/mods/install-vllm-rust-tool-parser/_rust_tool_parser.abi3.so" | awk '{print $1}')"
[[ "${actual}" == "${expected}" ]] || {
    echo "Rust parser checksum mismatch: ${actual}" >&2
    exit 1
}

echo "Runtime ready: ${RUNTIME_DIR} @ ${UPSTREAM_COMMIT}"
