#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

printf '%-16s %-12s %s\n' NODE CONTAINER STATUS
while IFS= read -r node; do
    if [[ "${node}" == "$(head_node)" ]]; then
        status="$(docker inspect -f '{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo missing)"
    else
        status="$(ssh -o BatchMode=yes -o ConnectTimeout=5 "${node}" \
            "docker inspect -f '{{.State.Status}}' '${CONTAINER_NAME}' 2>/dev/null || echo missing" 2>/dev/null || echo unreachable)"
    fi
    printf '%-16s %-12s %s\n' "${node}" "${CONTAINER_NAME}" "${status}"
done < <(tr ',' '\n' <<<"${CLUSTER_NODES}")

base="$(api_base)"
printf '\nAPI: '
if code="$(curl -sS --max-time 3 -o /dev/null -w '%{http_code}' "${base}/health" 2>/dev/null)"; then
    echo "${base} (${code})"
else
    echo "${base} (unreachable)"
fi
