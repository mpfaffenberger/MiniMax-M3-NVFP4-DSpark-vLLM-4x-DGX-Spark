# Full native TP eager llama-benchy checkpoint — 2026-07-23

## Summary

The complete submission matrix finished successfully on four DGX Spark / ASUS
GX10 nodes using native multi-node vLLM TP=4, DSpark `k=8`, and eager execution.

- llama-benchy: 0.4.0
- requests: **702/702 successful**
- errors: **0**
- elapsed: approximately 3h 35m
- maximum observed peak: **108.33 tok/s** at depth 4096 / C10
- best aggregate `tg128`: **56.89 tok/s** at depth 0 / C5
- API health after completion: HTTP 200
- no OOM, NCCL, NVRM, or thermal-throttling events

Full submission CSV: [`2026-07-23-native-eager-full.csv`](2026-07-23-native-eager-full.csv).

## Command

```bash
llama-benchy \
  --base-url http://10.0.0.46:8000/v1 \
  --model nvidia/MiniMax-M3-NVFP4 \
  --depth 0 4096 8192 16384 32768 65535 100000 \
  --pp 2048 \
  --tg 128 \
  --enable-prefix-caching \
  --concurrency 1 2 5 10 \
  --save-result results.csv \
  --format csv
```

The default three runs per cell were retained. Prefix-caching measurements add
separate context-load and inference phases at non-zero depths.

## Final generation throughput

Aggregate `tg128` throughput in tokens/second:

| Context depth | C1 | C2 | C5 | C10 |
|---:|---:|---:|---:|---:|
| 0 | 38.99 | 54.17 | **56.89** | 47.98 |
| 4,096 | 42.27 | 47.55 | **53.97** | 49.45 |
| 8,192 | 33.89 | **53.59** | 52.37 | 46.52 |
| 16,384 | 35.53 | **50.85** | 42.10 | 42.54 |
| 32,768 | 36.73 | 39.48 | 40.99 | **41.52** |
| 65,535 | 34.43 | 34.78 | **37.54** | 5.25 |
| 100,000 | 29.64 | **38.24** | 3.96 | 2.92 |

## Peak throughput

| Cell | Peak tok/s |
|---|---:|
| depth 4,096 / C10 | **108.33** |
| depth 16,384 / C10 | 104.33 |
| depth 32,768 / C10 | 104.33 |
| depth 4,096 / C5 | 98.67 |
| depth 0 / C10 | 98.00 |
| depth 0 / C5 | 97.67 |
| depth 8,192 / C10 | 97.33 |

## Context prefill throughput

C1 context/prompt processing:

| Context depth | Prefill tok/s |
|---:|---:|
| 0 | 2,031.69 |
| 4,096 | 2,197.13 |
| 8,192 | 2,358.98 |
| 16,384 | **2,386.08** |
| 32,768 | 2,376.57 |
| 65,535 | 2,313.66 |
| 100,000 | 2,263.91 |

During concurrent 100k context ingestion, vLLM log windows reached roughly
10,000 prompt tok/s aggregate.

## Interpretation

- C5 is the throughput sweet spot for short contexts.
- C2 is the safe throughput profile at 100k context.
- C10 remains useful through 32k but collapses at 65k and 100k because the
  473k-token KV pool and `max_num_seqs=4` force extensive queueing. The result
  measures end-to-end service throughput, so queue delay is correctly visible.
- C5 at 100k also crosses the practical cache concurrency boundary and falls to
  3.96 tok/s aggregate. More requested concurrency is very much not free.
- Single-stream decode remains 29.64 tok/s at 100k and 34–42 tok/s through 65k.
- Native eager outperformed native breakable CUDA graphs by 33–102% in the
  screening matrix and avoids Ray's graph-startup shared-memory wedge.
