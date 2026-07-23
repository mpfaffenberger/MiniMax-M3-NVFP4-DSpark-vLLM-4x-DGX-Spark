#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
readonly VLLM_REF="b44311b6ef9232d1f345f4b55adef7abc223f0e7"
readonly FLASHINFER_REF="771b7d47"
IMAGE="${IMAGE:-vllm-node-tf5-minimax-m3-dspark-20260722}"
BUILD_JOBS="${BUILD_JOBS:-1}"

command -v docker >/dev/null || {
    echo "docker is required" >&2
    exit 1
}

exec docker buildx build \
    --load \
    --platform linux/arm64 \
    --file "${ROOT}/container/Dockerfile" \
    --tag "${IMAGE}" \
    --build-arg "BUILD_JOBS=${BUILD_JOBS}" \
    --build-arg "VLLM_REF=${VLLM_REF}" \
    --build-arg "FLASHINFER_REF=${FLASHINFER_REF}" \
    --build-arg PRE_TRANSFORMERS=1 \
    --build-arg TORCH_CUDA_ARCH_LIST=12.1a \
    --build-arg FLASHINFER_CUDA_ARCH_LIST=12.1a \
    "${ROOT}/container"
