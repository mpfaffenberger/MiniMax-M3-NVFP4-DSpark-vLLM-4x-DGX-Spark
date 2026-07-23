#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config
[[ -x "${RUNTIME_DIR}/launch-cluster.sh" ]] || {
    echo "Runtime is not bootstrapped; nothing to stop." >&2
    exit 1
}
cd "${RUNTIME_DIR}"
./launch-cluster.sh -n "${CLUSTER_NODES}" --name "${CONTAINER_NAME}" stop
