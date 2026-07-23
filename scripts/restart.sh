#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

"${REPO_ROOT}/scripts/stop.sh"

reclaim='sync; echo 3 > /proc/sys/vm/drop_caches'
echo "Reclaiming unified-memory page cache on $(head_node)..."
sudo -n sh -c "${reclaim}"
free -h

while IFS= read -r worker; do
    echo "Reclaiming unified-memory page cache on ${worker}..."
    ssh -o BatchMode=yes "${worker}" \
        "sudo -n sh -c '${reclaim}'; free -h"
done < <(worker_nodes)

"${REPO_ROOT}/scripts/start.sh"
