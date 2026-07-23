#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
IMAGE_FILE="${ROOT}/container/image.env"

[[ -f "${IMAGE_FILE}" ]] || {
    echo "${IMAGE_FILE} is missing; publish and pin the image first" >&2
    exit 1
}
# shellcheck source=/dev/null
source "${IMAGE_FILE}"
: "${IMAGE_REF:?IMAGE_REF is missing from container/image.env}"

nodes="${1:-}"
if [[ -z "${nodes}" && -f "${ROOT}/.env" ]]; then
    nodes="$(sed -n 's/^CLUSTER_NODES=["'"']\{0,1\}\([^"'"']*\)["'"']\{0,1\}$/\1/p' "${ROOT}/.env" | tail -1)"
fi
[[ -n "${nodes}" ]] || {
    echo "Usage: $0 HEAD,WORKER1,WORKER2,..." >&2
    exit 1
}

IFS=',' read -r -a hosts <<< "${nodes}"
head="${hosts[0]}"
printf 'Pulling %s on the head node...\n' "${IMAGE_REF}"
docker pull "${IMAGE_REF}"

pids=()
for host in "${hosts[@]:1}"; do
    echo "Pulling on ${host}..."
    ssh -o BatchMode=yes "${host}" docker pull "${IMAGE_REF}" &
    pids+=("$!")
done
for pid in "${pids[@]}"; do
    wait "${pid}"
done

format='{{.Architecture}} {{index .RepoDigests 0}}'
printf '%s: ' "${head}"
docker image inspect "${IMAGE_REF}" --format "${format}"
quoted_ref="$(printf '%q' "${IMAGE_REF}")"
for host in "${hosts[@]:1}"; do
    printf '%s: ' "${host}"
    ssh -o BatchMode=yes "${host}" \
        "docker image inspect ${quoted_ref} --format '${format}'"
done

echo "Pinned image installed on all nodes."
