#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config
require_command rsync
require_command sha256sum

HF_HOME="${HF_HOME:-${HOME}/.cache/huggingface}"
readonly HUB="${HF_HOME}/hub"
readonly TARGET_ID="nvidia/MiniMax-M3-NVFP4"
readonly TARGET_REV="901464083161bf8612a29ff7ad29914cd4ab4a85"
readonly DRAFT_ID="nvidia/MiniMax-M3-DSpark"
readonly DRAFT_REV="e82db0e1895bc4e0c339ce670b2b553899a57f59"
readonly NCCL_SHA256="0bf24802ae809c796f216ec2a789c74e3dde8d31ac3c27aa068c8ef67e2436dc"

hf_download() {
    local model="$1" revision="$2"
    if command -v hf >/dev/null 2>&1; then
        hf download "${model}" --revision "${revision}"
    elif command -v uvx >/dev/null 2>&1; then
        uvx --from huggingface_hub hf download "${model}" --revision "${revision}"
    else
        echo "Install the Hugging Face CLI ('hf') or uvx first." >&2
        exit 1
    fi
}

model_cache_dir() {
    printf '%s/models--%s\n' "${HUB}" "${1//\//--}"
}

echo "Downloading pinned target snapshot..."
HF_HOME="${HF_HOME}" hf_download "${TARGET_ID}" "${TARGET_REV}"
echo "Downloading pinned DSpark snapshot..."
HF_HOME="${HF_HOME}" hf_download "${DRAFT_ID}" "${DRAFT_REV}"

nccl_dest="${HUB}/nccl-2.30.4/libnccl.so.2"
if [[ -n "${NCCL_LIBRARY:-}" ]]; then
    mkdir -p "$(dirname "${nccl_dest}")"
    cp "${NCCL_LIBRARY}" "${nccl_dest}"
fi
[[ -f "${nccl_dest}" ]] || {
    echo "NCCL 2.30.4 is required but ${nccl_dest} is missing." >&2
    echo "Set NCCL_LIBRARY=/path/to/libnccl.so.2 and rerun." >&2
    exit 1
}
echo "${NCCL_SHA256}  ${nccl_dest}" | sha256sum --check

mapfile -t workers < <(worker_nodes)
for worker in "${workers[@]}"; do
    echo "Syncing pinned caches to ${worker}..."
    # Expansion is intentionally local: every node uses the same configured cache path.
    # shellcheck disable=SC2029
    ssh "${worker}" "mkdir -p '${HUB}'"
    for model in "${TARGET_ID}" "${DRAFT_ID}"; do
        rsync -a --info=progress2 "$(model_cache_dir "${model}")" "${worker}:${HUB}/"
    done
    rsync -a "${HUB}/nccl-2.30.4" "${worker}:${HUB}/"
    # shellcheck disable=SC2029
    ssh "${worker}" "echo '${NCCL_SHA256}  ${nccl_dest}' | sha256sum --check"
done

echo "Pinned model and NCCL caches are ready on all nodes."
