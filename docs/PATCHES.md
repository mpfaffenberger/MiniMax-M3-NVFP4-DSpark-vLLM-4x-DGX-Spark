# Runtime patches

All mods run inside every rank's container before model launch. They are
idempotent and validate their result instead of blindly editing whatever file
happens to have a familiar name.

## `fix-nccl-2.30.4`

Replaces the image's NCCL 2.29.7 library with NCCL 2.30.4+cuda13.2 on every
node. This avoids the GB10 shared-memory broadcast wedge observed under load.
The library is not redistributed here; `prepare-models.sh` verifies SHA-256
`0bf24802ae809c796f216ec2a789c74e3dde8d31ac3c27aa068c8ef67e2436dc`.

## `fix-minimax-m3-nvfp4-correctness-48929`

Applies the runtime-relevant MiniMax-M3 NVFP4 changes from vLLM PR #48929.
Affected areas include FP4 MoE scales, sparse attention, and indexer layouts.
The mod uses forward/reverse dry runs and compiles every modified Python file.

## `install-vllm-rust-tool-parser`

Installs `vllm._rust_tool_parser`, built from vLLM commit
`b44311b6ef9232d1f345f4b55adef7abc223f0e7` for arm64 with Rust 1.95 and
PyO3 ABI3. Artifact SHA-256:

```text
346e6e0a64613c20decc0cf97bfcdd1a02b18b836d650e23097697c4a80af275
```

The installer imports the module, validates incremental name/argument deltas,
and parses a typed MiniMax tool-call fixture. Source patches stream exact
schema-typed top-level strings continuously (including large `create_file`
content) and retain completed-boundary buffering for typed or nested XML values.
Rebuild provenance and patch checksums are in the mod's README.

## `fix-minimax-m3-streaming-reasoning`

MiniMax's system instructions contain a closed `<mm:think>` example. The
generic prompt scan treated that example as state for the upcoming assistant
turn, causing adaptive SSE output to leak raw reasoning tags as content.

The patch preserves `thinking_mode` and initializes state as follows:

- `disabled`: reasoning has ended;
- `enabled`: inspect existing markers;
- adaptive/default: generation deltas decide.

Its fixture validates all three paths.

## `rename-reasoning-to-reasoning-content`

Maps internal `ChatMessage.reasoning` and `DeltaMessage.reasoning` to the
OpenAI-compatible `reasoning_content` wire key at Pydantic serialization time.
The old key is absent in regular JSON and SSE deltas.

## `skip-empty-dspark-cudagraph-capture`

MiniMax target execution supports vLLM's breakable `PIECEWISE` CUDA graphs,
while the DSpark speculator only supports `FULL` graphs. With an explicit
piecewise target profile, the DSpark graph manager has no capture candidates.
The pinned vLLM build still entered its distributed capture context and wedged
four-node startup. This guard returns early when `needs_capture()` is false;
target graphs remain enabled and the draft step remains eager.

## `guard-minimax-m3-modelopt-fp4`

Refuses to instantiate MiniMax MoE experts unless quantization resolves to
`modelopt_fp4` or `modelopt_mixed`. Without this guard, a misdetected checkpoint
can silently allocate BF16 experts and exhaust unified memory.

## Base orchestrator patch

`patches/spark-vllm-docker.patch` makes two narrow changes to the pinned base:

1. MiniMax-specific vLLM refs do not fail the generic image build when two old
   regression reverts are no longer applicable.
2. `/workspace` is created before the launch script is copied into containers.
