# Validated four-node checkpoint — 2026-07-23

## Runtime

- Target: `nvidia/MiniMax-M3-NVFP4`
- Drafter: `nvidia/MiniMax-M3-DSpark`
- Hardware: 4× NVIDIA DGX Spark / GB10
- Tensor parallelism: 4 through Ray
- DSpark speculative budget: 8 tokens
- KV cache: FP8
- Context ceiling: 262,144
- Max sequences: 4

## Cumulative counters

```text
spec_decode_num_drafts_total              719
spec_decode_num_draft_tokens_total      5,752
spec_decode_num_accepted_tokens_total   1,228
generation_tokens_total                 1,954
prompt_tokens_total                    58,602
request_decode_time_seconds_sum         67.02
request_success_total                       11 stop / 0 error
```

Derived:

- token-level acceptance: `1,228 / 5,752` = **21.3%**
- accepted tokens per draft: `1,228 / 719` = **1.71**
- aggregate decode throughput: `1,954 / 67.02` = **29.2 tok/s**

## Representative 10-second windows

| UTC | Generation tok/s | Mean acceptance length | Accepted tok/s | Drafted tok/s |
|---|---:|---:|---:|---:|
| 13:03:41 | 22.0 | 1.93 | 10.60 | 91.19 |
| 13:03:51 | 25.0 | 2.54 | 15.10 | 78.39 |
| 13:04:01 | **37.5** | **3.94** | **27.90** | 75.99 |
| 13:04:11 | 20.6 | 2.11 | 10.80 | 77.59 |
| 13:04:21 | 22.1 | 2.82 | 14.20 | 62.39 |
| 13:05:21 | 29.8 | 2.71 | 18.80 | 87.98 |

Prefix-cache hit rate rose from 0% through 44.9%, 61.1%, 69.0%, and 77.8%.

## Functional gates

- regular response uses `reasoning_content` and omits `reasoning`;
- adaptive SSE streams reasoning separately and returns clean content;
- disabled thinking returns clean content and null reasoning;
- automatic tool call returns valid typed JSON arguments;
- health endpoint returns HTTP 200;
- no request errors, OOM reports, or NVRM errors.

## Interpretation

The 8-token speculative budget does not imply eight accepted tokens per target
step. The observed mean was 1.71. Peak windows were substantially faster than
cold or short requests, especially as prefix caching warmed. These figures are
a reproducibility checkpoint, not a claim that every prompt sustains 37.5 tok/s.
