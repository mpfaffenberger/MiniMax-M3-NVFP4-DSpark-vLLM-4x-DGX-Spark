#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

args=(--tail "${TAIL:-200}")
[[ "${1:-}" == "-f" || "${1:-}" == "--follow" ]] && args+=(--follow)
docker logs "${args[@]}" "${CONTAINER_NAME}"
