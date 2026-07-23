# SparkRun benchmark submission bundle

Upload these two files to the SparkRun benchmark form:

1. [`recipe.yaml`](recipe.yaml) as the recipe YAML.
2. [`../results.csv`](../results.csv) as the llama-benchy results CSV.

## Submission identity

- Model: `nvidia/MiniMax-M3-NVFP4`
- Draft model: `nvidia/MiniMax-M3-DSpark`
- Hardware: 4x NVIDIA DGX Spark / ASUS GX10, one GB10 GPU per node
- Serving: native multi-node vLLM TP=4 (no Ray)
- Speculation: NVIDIA DSpark, block size / speculative budget 8
- KV cache: FP8
- Context ceiling: 262,144 tokens
- Benchmark: llama-benchy 0.4.0, 702/702 requests, zero errors

## Reproduce

Current `eugr/spark-vllm-docker` defaults to native no-Ray execution for
multi-node runs. From this repository:

```bash
cp .env.example .env
$EDITOR .env
make bootstrap
NCCL_LIBRARY=/path/to/libnccl.so.2 make prepare
make setup
```

Equivalent direct invocation inside the bootstrapped runtime:

```bash
./run-recipe.sh minimax-m3-nvidia-nvfp4-dspark \
  --nodes HEAD,WORKER1,WORKER2,WORKER3 \
  --no-ray \
  --daemon
```

`--no-ray` is explicit above for readability and compatibility; it is the
current upstream default.

Benchmark command:

```bash
llama-benchy \
  --base-url http://HEAD:8000/v1 \
  --model nvidia/MiniMax-M3-NVFP4 \
  --depth 0 4096 8192 16384 32768 65535 100000 \
  --pp 2048 \
  --tg 128 \
  --enable-prefix-caching \
  --concurrency 1 2 5 10 \
  --save-result results.csv
```

## Integrity

```text
results.csv SHA-256:
0dc298fc7c57ca5de91ee066fa1155b14746b53f33cca4c39c139eabc7c511ed
```

The submission recipe uses portable Hugging Face IDs pinned to the exact target
and draft revisions used by the benchmark. The production recipe intentionally
retains direct local snapshot paths and offline mode for the original cluster.
Static validation checks that performance-critical settings remain aligned while
rejecting machine-specific cache paths in the submission recipe.

Detailed interpretation and headline metrics are in
[`../benchmarks/2026-07-23-native-eager-full.md`](../benchmarks/2026-07-23-native-eager-full.md).
