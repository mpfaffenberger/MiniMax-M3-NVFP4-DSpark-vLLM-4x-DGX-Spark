# vLLM Rust tool-parser extension

Installs the optional `vllm._rust_tool_parser` PyO3 module that is missing from
the custom vLLM wheel.

## Provenance

- vLLM commit: `b44311b6ef9232d1f345f4b55adef7abc223f0e7`
- Crate: `rust/src/parser/python`
- Rust toolchain: `1.95`
- Target: `aarch64-unknown-linux-gnu`
- PyO3: `abi3-py38`, extension-module linkage
- Artifact SHA-256:
  `cfda01f2ba3ebdb4b7970c0b140be8874eba5f43087682424e50e141fd51df78`

The extension was built inside `vllm-node-tf5-minimax-m3-dspark-20260722`,
matching the production Python 3.12/aarch64 runtime. `PYO3_BUILD_EXTENSION_MODULE=1`
is required; without it, a direct Cargo build incorrectly links `libpython3.12`.

## Build command

From an exact checkout of the vLLM commit:

```bash
PYO3_PYTHON=/usr/bin/python3 \
PYO3_BUILD_EXTENSION_MODULE=1 \
cargo +1.95 build \
  --manifest-path rust/src/parser/python/Cargo.toml \
  --release \
  --features pyo3/abi3-py38
```

Copy `target/release/lib_rust_tool_parser.so` to:

```text
_rust_tool_parser.abi3.so
```

Then update the checksum in `run.sh` and rerun its disposable-container tests.

## Runtime behavior

`run.sh` is idempotent and verifies the artifact checksum before and after
installation. It also imports the module and parses a MiniMax-M3 tool-call
fixture, including typed JSON arguments, before allowing model launch.
