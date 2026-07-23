#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly ENV_FILE="${ENV_FILE:-${REPO_ROOT}/.env}"

load_config() {
    if [[ ! -f "${ENV_FILE}" ]]; then
        echo "Missing ${ENV_FILE}. Run: cp .env.example .env" >&2
        exit 1
    fi
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a

    : "${CLUSTER_NODES:?CLUSTER_NODES is required}"
    : "${CONTAINER_NAME:=minimax_m3_dspark}"
    : "${API_PORT:=8000}"
    RUNTIME_DIR="${RUNTIME_DIR:-${REPO_ROOT}/.runtime/spark-vllm-docker}"
    export RUNTIME_DIR
}

head_node() {
    printf '%s\n' "${CLUSTER_NODES%%,*}"
}

worker_nodes() {
    tr ',' '\n' <<<"${CLUSTER_NODES}" | tail -n +2
}

api_base() {
    printf 'http://%s:%s\n' "$(head_node)" "${API_PORT}"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Required command not found: $1" >&2
        exit 1
    }
}
