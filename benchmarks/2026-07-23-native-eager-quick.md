# Native TP eager quick checkpoint — 2026-07-23

## Result

Native multi-node vLLM TP=4 with eager execution is the winning production
profile. It avoids Ray's graph-startup wedge and substantially outperforms
breakable piecewise CUDA graphs on the same native executor.

All 54 llama-benchy requests completed with zero errors. The API remained
healthy, and reasoning, adaptive SSE, disabled thinking, and typed tool calling
all passed.

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
  --save-result results/native-eager-quick.csv \
  --format csv
```

## Official llama-benchy rows

| Test | Aggregate tok/s | Per-request tok/s | Peak aggregate tok/s |
|---|---:|---:|---:|
| tg128 d0 C1 | 36.70 | 36.70 | 53.33 |
| tg128 d0 C5 | 50.91 | 19.78 | 88.00 |
| ctx_tg d4096 C1 | 36.19 | 36.19 | 50.67 |
| tg128 d4096 C1 | 34.12 | 34.12 | 44.67 |
| ctx_tg d4096 C5 | 45.16 | 19.13 | 91.67 |
| tg128 d4096 C5 | 47.54 | 19.53 | **97.33** |

Prefill highlights:

- d0 C1: 2,031.6 tok/s
- d4096 context load C1: 2,255.7 tok/s
- d4096 context load C5: 1,321.1 aggregate tok/s

Full CSV: [`2026-07-23-native-eager-quick.csv`](2026-07-23-native-eager-quick.csv).

## Native eager versus native piecewise graphs

| Cell | Native graphs | Native eager | Eager gain |
|---|---:|---:|---:|
| d0 C1 | 18.16 | 36.70 | +102.1% |
| d0 C5 aggregate | 34.76 | 50.91 | +46.5% |
| d4096 C1 | 19.87 | 34.12 | +71.7% |
| d4096 C5 aggregate | 35.73 | 47.54 | +33.1% |

## Executor comparison

Reconstructed mean per-request decode speed from progress streams:

| Cell | Ray eager | Native eager | Native change |
|---|---:|---:|---:|
| d0 C1 | 35.11 | 38.52 | +9.7% |
| d0 C5 | 20.39 | 20.85 | +2.3% |
| d4096 C1 | 42.37 | 36.65 | -13.5% |
| d4096 C5 | 20.02 | 20.18 | +0.8% |

The Ray baseline was an aborted larger run rather than an isolated paired run,
so this executor table is directional. Native eager is roughly equivalent under
concurrency, faster in the short C1 cell, simpler operationally, and avoids the
Ray shared-memory startup failure seen with graph capture.
