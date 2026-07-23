# Reproducible MiniMax M3 vLLM container

This directory vendors the exact patched Docker build context used for the
validated benchmark image. It provides the source-rebuild half of the
reproducibility story; the public image digest provides the immutable binary
half.

## Validated image

```text
Local tag:      vllm-node-tf5-minimax-m3-dspark-20260722
Local image ID: sha256:885c0d34fbecd82f0467533f4196e5437326fef6c42f92949a937e76d56cc0c1
Registry tag:   ghcr.io/mpfaffenberger/minimax-m3-nvfp4-dspark-vllm:b44311b6-20260722-arm64
Manifest:       sha256:de616b32bf1ef9cdf809830a1faf1e57f74c136b8e415e854607ebc4efd9648b
Platform:       linux/arm64
Size:           18.93 GiB uncompressed; approximately 8.35 GiB compressed
```

The image contains no model weights, Hugging Face cache, or files larger than
2 GiB. Models remain external and are identified by pinned Hugging Face
revisions in the SparkRun submission recipe.

## Provenance

| Component | Pin |
|---|---|
| `eugr/spark-vllm-docker` | `08c34dd8262e5b429a8cbf36bcf15507628c2999` |
| vLLM | `b44311b6ef9232d1f345f4b55adef7abc223f0e7` |
| vLLM version | `0.23.1rc1.dev1388+gb44311b6e.d20260722.cu132` |
| FlashInfer | `771b7d47` |
| CUDA base | `nvidia/cuda:13.2.0-devel-ubuntu24.04` |
| GPU architecture | `12.1a` / GB10 arm64 |

`Dockerfile` is the upstream file after applying
`../patches/spark-vllm-docker.patch`. Runtime MiniMax correctness, NCCL,
reasoning, and tool-parser fixes are deliberately applied as recipe mods rather
than hidden inside the base image.

## Build from source

On an arm64 DGX Spark host:

```bash
./scripts/build-container.sh
./scripts/audit-container.sh
```

The build pins source revisions but is not promised to be bit-for-bit identical:
APT and Python package indexes are mutable. The registry digest is the canonical
binary reproduction mechanism.

## Publish to GHCR

Create a GitHub token with `write:packages`, then pass it through stdin-backed
Docker login via the environment:

```bash
read -rsp 'GHCR token: ' GHCR_TOKEN
export GHCR_TOKEN
./scripts/publish-container.sh
unset GHCR_TOKEN
```

Publishing generates `container/image.env`. Commit that file and pin the
submission recipe's `container` value to its immutable `IMAGE_REF`; never pin a
reproducibility recipe to only the mutable tag.

Never publish model weights in the image.

## Install the immutable image on a cluster

```bash
./scripts/install-container.sh HEAD,WORKER1,WORKER2,WORKER3
```

This pulls the digest-pinned image on every node and verifies the installed
architecture and repository digest. Current `spark-vllm-docker` does not pull a
missing recipe image automatically, so this explicit installation step is
required before `run-recipe.sh`.
