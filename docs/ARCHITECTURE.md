# Architecture

## Deployment boundary

This repository is a versioned overlay, not a fork of the complete cluster
orchestrator. `scripts/bootstrap.sh` clones `eugr/spark-vllm-docker` at commit
`08c34dd8262e5b429a8cbf36bcf15507628c2999` into the ignored `.runtime/`
directory, applies `patches/spark-vllm-docker.patch`, and copies in the recipe
and mods.

That split keeps responsibilities boring and clear:

- **spark-vllm-docker:** image construction, SSH, Docker, and native rank launch.
- **this repository:** MiniMax model profile, exact patches, validation, and docs.
- **vLLM:** OpenAI API, scheduling, TP execution, reasoning, tools, and DSpark.

## Request path

1. The head node accepts an OpenAI-compatible request on port 8000.
2. vLLM renders MiniMax-M3's chat template and initializes reasoning/tool parsers.
3. Native vLLM multiprocessing dispatches work across four TP ranks.
4. MiniMax-M3-DSpark proposes up to eight tokens.
5. MiniMax-M3-NVFP4 verifies the proposed chain in a target forward pass.
6. Accepted tokens enter the response; rejection resumes target decoding.
7. The serializer maps internal `reasoning` to wire-level `reasoning_content`.

## Why TP=4

The native NVFP4 checkpoint plus runtime state is distributed across four GB10
nodes. Each node loaded about 59.77 GiB of model state in the validated run.
vLLM launches one native process per node; PyTorch distributed and NCCL carry
tensor-parallel collectives over the RoCE fabric without a Ray control plane.

## Memory profile

The recipe uses:

- `gpu_memory_utilization=0.80`
- FP8 KV cache
- 262,144 maximum model length
- 8,192 maximum batched tokens
- 4 maximum sequences
- eager execution on the native multi-node TP backend

A controlled native-TP experiment successfully enabled vLLM's breakable
`PIECEWISE` CUDA graphs for the target while leaving DSpark eager. It passed all
correctness gates but regressed matched llama-benchy decode throughput by
33–54%, so the production recipe remains eager. See the benchmark checkpoint
for evidence rather than assuming every graph is automatically faster.

Validated host memory after startup was approximately 89–93 GiB used per node,
leaving 28–31 GiB available. Unified-memory systems have very little patience
for fuzzy capacity planning, hence the quantization guard.

## Offline runtime

Serving uses `HF_HUB_OFFLINE=1` and `TRANSFORMERS_OFFLINE=1`. Snapshot revisions
are pinned and must be prepared on every node before launch. Runtime behavior
therefore cannot silently change because a model repository moved `main`.
