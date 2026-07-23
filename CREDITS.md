# Credits and provenance

- **NVIDIA** publishes the MiniMax-M3 NVFP4 target and DSpark draft checkpoints,
  DGX Spark platform, CUDA, NCCL, ModelOpt, and related runtime components.
- **MiniMax** created the MiniMax-M3 model family.
- **vLLM contributors** provide the serving engine, Ray execution path, OpenAI
  API, MiniMax integration, and speculative-decoding implementation.
- **Eugene Rakhmatulin (`eugr`)** authored
  [`spark-vllm-docker`](https://github.com/eugr/spark-vllm-docker), used here as
  the pinned cluster/image orchestration layer under its MIT license.
- **Tony Deangelo (`tonyd2wild`)** authored
  [`DeepSeek-v4-Flash-DSpark-1M-NVFP4-KV-2x-DGX-Spark`](https://github.com/tonyd2wild/DeepSeek-v4-Flash-DSpark-1M-NVFP4-KV-2x-DGX-Spark),
  which inspired this repository's operational layout and evidence-first docs.
- The NVFP4 runtime diff is derived from **vLLM PR #48929** and retains upstream
  project licensing.

Repository-authored wrappers and documentation are MIT licensed. The model
weights and NVIDIA artifacts are not relicensed or redistributed by this
repository. The arm64 Rust parser binary is a build artifact of vLLM source;
its exact source commit, build flags, and checksum are documented beside it.
