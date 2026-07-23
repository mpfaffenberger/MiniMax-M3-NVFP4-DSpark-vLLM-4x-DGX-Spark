# Native TP + piecewise CUDA graph quick checkpoint — 2026-07-23

## Purpose

Test whether replacing Ray with native multi-node vLLM TP=4 allows MiniMax-M3
target execution to use breakable piecewise CUDA graphs correctly and faster.
This is a screening benchmark, not the full submission matrix.

## Runtime

- Four DGX Spark nodes, native vLLM multi-node TP=4
- PyTorch distributed and NCCL 2.30.4; no Ray processes
- MiniMax-M3-NVFP4 target, MiniMax-M3-DSpark `k=8`
- FP8 KV cache, max sequences 4
- `cudagraph_mode=PIECEWISE`
- Breakable target graphs: enabled on all ranks
- DSpark full graph: unsupported in piecewise mode and skipped
- llama-benchy 0.4.0

## Command

```bash
llama-benchy \
  --base-url http://10.0.0.46:8000/v1 \
  --model nvidia/MiniMax-M3-NVFP4 \
  --depth 0 4096 \
  --pp 2048 \
  --tg 128 \
  --enable-prefix-caching \
  --concurrency 1 5 \
  --runs 3 \
  --save-result results/cudagraph-native-quick.csv \
  --format csv
```

All 54 requests completed with zero errors. Reasoning, SSE, disabled-thinking,
and typed tool-call smoke tests also passed.

## Official llama-benchy rows

| Test | Aggregate tok/s | Per-request tok/s |
|---|---:|---:|
| tg128 d0 C1 | 18.16 | 18.16 |
| tg128 d0 C5 | 34.76 | 12.75 |
| ctx_tg d4096 C1 | 17.74 | 17.74 |
| tg128 d4096 C1 | 19.87 | 19.87 |
| ctx_tg d4096 C5 | 32.31 | 12.35 |
| tg128 d4096 C5 | 35.73 | 13.35 |

Full CSV: [`2026-07-23-native-piecewise-cudagraph-quick.csv`](2026-07-23-native-piecewise-cudagraph-quick.csv).

## Screening comparison

The aborted eager-Ray baseline contained the same cells. Reconstructing mean
per-request decode throughput from both progress streams produced:

| Cell | Eager + Ray | Native + graphs | Change |
|---|---:|---:|---:|
| d0 C1 | 35.11 | 19.13 | -45.5% |
| d0 C5 | 20.39 | 13.43 | -34.1% |
| d4096 C1 | 42.37 | 19.64 | -53.6% |
| d4096 C5 | 20.02 | 13.40 | -33.1% |

This changes both executor and graph mode, so it does not isolate causation.
However, every matched cell regressed enough that running the full long-context
matrix on this profile is not justified. The next controlled experiment should
keep native TP and disable piecewise graphs, then repeat this exact quick matrix.
