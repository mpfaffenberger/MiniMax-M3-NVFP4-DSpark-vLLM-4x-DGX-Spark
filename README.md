# MiniMax M3 NVFP4 + DSpark on Native Multi-Node vLLM

> A validated four-node NVIDIA DGX Spark deployment for
> [`nvidia/MiniMax-M3-NVFP4`](https://huggingface.co/nvidia/MiniMax-M3-NVFP4),
> accelerated by [`nvidia/MiniMax-M3-DSpark`](https://huggingface.co/nvidia/MiniMax-M3-DSpark)
> speculative decoding and served through the OpenAI-compatible vLLM API.

[![Hardware](https://img.shields.io/badge/hardware-4×_DGX_Spark-76B900)](#hardware)
[![vLLM](https://img.shields.io/badge/vLLM-pinned-blue)](docs/ARCHITECTURE.md)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## What you get

- **4× GB10 / DGX Spark**, one GPU per node, native vLLM tensor parallelism 4.
- Native NVIDIA **ModelOpt NVFP4** target weights.
- NVIDIA **DSpark**, drafting 8 speculative tokens per target step.
- **FP8 KV cache** and a validated **262,144-token** serving ceiling.
- OpenAI-compatible chat completions at `http://HEAD:8000/v1`.
- MiniMax reasoning with `reasoning_content` in regular and SSE responses.
- Automatic MiniMax tool calls through the checksum-pinned Rust parser.
- Reproducible runtime pinning, idempotent mods, smoke tests, and live metrics.

## Validated tuned checkpoint

Measured with llama-benchy 0.4.0 on a four-node GB10 cluster on 2026-07-23:

| Metric | Result |
|---|---:|
| Decode, depth 0 / C1 | **38.99 tok/s** |
| Aggregate decode, depth 0 / C5 | **56.89 tok/s** |
| Aggregate decode, depth 4096 / C5 | **53.97 tok/s** |
| Peak decode, depth 4096 / C10 | **108.33 tok/s** |
| Decode, depth 100k / C1 | **29.64 tok/s** |
| Context prefill, depth 16k / C1 | **2,386.1 tok/s** |
| Successful full-benchmark requests | **702/702** |
| Server/OOM/NVRM errors | **0** |

These are observed results, not an enchanted marketing benchmark. Prompt shape,
output length, concurrency, cache warmth, and fabric quality all matter. See the
[`full native eager checkpoint`](benchmarks/2026-07-23-native-eager-full.md), the
[`CUDA-graph comparison`](benchmarks/2026-07-23-native-piecewise-cudagraph-quick.md),
and the original [`Ray baseline`](benchmarks/2026-07-23-validated-checkpoint.md).

### SparkRun submission

The upload-ready pair is [`submission/recipe.yaml`](submission/recipe.yaml) and
[`results.csv`](results.csv). Reproduction and checksum notes are in the
[`submission bundle README`](submission/README.md).

## Architecture

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the deployment architecture,
request path, tensor-parallel topology, and memory profile.

## Hardware

The validated topology is:

- 4× NVIDIA DGX Spark / GB10, 128 GB unified memory per node.
- One GPU and one vLLM tensor-parallel rank per node.
- RoCE fabric with two active CX-7 interfaces per node.
- Passwordless SSH from the head node to every worker.
- Docker, NVIDIA Container Toolkit, Git, Python 3.10+, `rsync`, and `uvx` or `hf`.
- The same model cache and NCCL 2.30.4 library on every node.

This recipe is intentionally cluster-only. Making a giant model fit on one
Spark by changing a flag is not optimization; it is fiction with YAML syntax.

## Quick start

### 1. Configure the cluster

```bash
git clone <this-repository-url>
cd MiniMax-M3-NVFP4-DSpark-vLLM-4x-DGX-Spark
cp .env.example .env
$EDITOR .env
```

The first address in `CLUSTER_NODES` is the native TP rank 0 and API host.
Update the fabric interface names for your machines.

### 2. Bootstrap the pinned orchestrator

```bash
make bootstrap
make validate
```

This clones `eugr/spark-vllm-docker` under `.runtime/` at the exact tested
commit, applies the small required base patch, and overlays this repository's
recipe and mods. It refuses to mutate an unexpected checkout.

### 3. Prepare weights and NCCL

Obtain the arm64 CUDA 13.2 NCCL 2.30.4 shared library through an authorized
NVIDIA distribution, then set its path:

```bash
NCCL_LIBRARY=/path/to/libnccl.so.2 make prepare
```

Preparation:

1. Downloads the exact target and draft revisions.
2. Verifies NCCL SHA-256 `0bf24802...e2436dc`.
3. Rsyncs both model caches and NCCL to every worker.

The weights are large. Yes, this step takes a while. No, `curl | vibes` cannot
make hundreds of gigabytes teleport.

### 4. Build and launch

First deployment:

```bash
make setup
```

Subsequent launches with the existing image and caches:

```bash
make start
```

Follow startup:

```bash
make logs
```

Model loading took about three minutes in the validated run. Wait for:

```text
Application startup complete.
```

### 5. Verify

```bash
make status
make smoke
make metrics
```

## API examples

### Reasoning

```bash
curl http://HEAD_NODE:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "nvidia/MiniMax-M3-NVFP4",
    "messages": [{"role": "user", "content": "What is 12 + 30?"}],
    "temperature": 0,
    "max_tokens": 128
  }'
```

Response messages expose:

```json
{
  "role": "assistant",
  "reasoning_content": "The user asks for a simple sum...",
  "content": "42"
}
```

The legacy `reasoning` key is intentionally absent. Streaming deltas use the
same `reasoning_content` name.

### Disable thinking

```json
{
  "chat_template_kwargs": {"thinking_mode": "disabled"}
}
```

### Tool calling

The server launches with:

```text
--enable-auto-tool-choice --tool-call-parser minimax_m3
```

Use standard OpenAI `tools` and `tool_choice` request fields. `make smoke`
validates typed JSON arguments with a weather-tool fixture.

## Runtime profile

| Setting | Value |
|---|---|
| Target | `nvidia/MiniMax-M3-NVFP4` |
| Drafter | `nvidia/MiniMax-M3-DSpark` |
| Tensor parallelism | 4 |
| Distributed backend | native multiprocessing / PyTorch distributed |
| Speculation | DSpark, `k=8` |
| KV cache | FP8 |
| Context | 262,144 tokens |
| Max batched tokens | 8,192 |
| Max sequences | 4 |
| GPU memory utilization | 0.80 |
| Load format | InstantTensor |
| Execution | eager (native TP) |

The exact source of truth is
[`recipes/minimax-m3-nvidia-nvfp4-dspark.yaml`](recipes/minimax-m3-nvidia-nvfp4-dspark.yaml).

## Operations

```bash
make status   # containers and API health
make logs     # follow head/API logs
make metrics  # DSpark acceptance and decode throughput
make smoke    # reasoning + disabled mode + tool calling
make stop     # stop all four containers
```

The endpoint has **no authentication or TLS**. Bind it only to a trusted
network or put an authenticated reverse proxy in front of it. The model being
clever does not make an open port clever.

## Patches and provenance

Every runtime modification is documented in [`docs/PATCHES.md`](docs/PATCHES.md)
and fails closed if its expected source or checksum does not match. Highlights:

- vLLM MiniMax-M3 NVFP4 correctness fixes from PR #48929.
- NCCL 2.30.4 deployment on every tensor-parallel rank.
- checksum-verified arm64 ABI3 Rust tool parser.
- adaptive streaming reasoning state fix.
- `reasoning` → `reasoning_content` wire compatibility.
- ModelOpt NVFP4 guard preventing accidental BF16 expert allocation.

## Troubleshooting

Start with [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md). The short list:

- A silent multi-node hang is usually fabric/NCCL, not a philosophical pause.
- `ModuleNotFoundError: vllm._rust_tool_parser` means the parser mod did not run.
- Raw `<mm:think>` in content means the streaming reasoning mod is missing.
- A sudden memory explosion means the ModelOpt quantization path was not selected.
- Never mix model snapshots or NCCL builds between ranks.

## Inspiration and credits

This project uses `eugr/spark-vllm-docker` as its pinned orchestration layer and
was structurally inspired by Tony Deangelo's excellent
[`DeepSeek-v4-Flash-DSpark-1M-NVFP4-KV-2x-DGX-Spark`](https://github.com/tonyd2wild/DeepSeek-v4-Flash-DSpark-1M-NVFP4-KV-2x-DGX-Spark)
repository. See [`CREDITS.md`](CREDITS.md) for full provenance.

## License

Repository-authored deployment code and documentation are MIT licensed. Model
weights, NVIDIA libraries, vLLM, copied upstream patches, and the embedded Rust
extension retain their respective upstream licenses. See [`CREDITS.md`](CREDITS.md).
