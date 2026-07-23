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
  `4c00bb276904de5a12d27b70eff97250eca54716559e06b042f17b6cc827e944`
- Incremental-streaming patch SHA-256:
  `116d7e69befe8204a7c54ef81fad823f1a32e70582d1d045bff786f2d92cd8a4`

The extension was built on an aarch64 DGX Spark host and tested inside
`vllm-node-tf5-minimax-m3-dspark-20260722`, matching production Python 3.12.
The `pyo3/extension-module` feature is required; without it, a direct Cargo
build incorrectly links a specific `libpython`.

## Build command

From an exact checkout of the vLLM commit:

```bash
git apply minimax-m3-incremental-streaming.patch
cargo +1.95 build \
  --release \
  -p vllm-tool-parser-py \
  --features 'pyo3/abi3-py38 pyo3/extension-module'
```

Copy `target/release/lib_rust_tool_parser.so` to:

```text
_rust_tool_parser.abi3.so
```

Then update the checksum in `run.sh` and rerun its disposable-container tests.

## Runtime behavior

`run.sh` is idempotent and verifies the artifact checksum before and after
installation. It imports the module, verifies incremental name/argument
fragments, and parses the coalesced typed MiniMax-M3 JSON fixture before model
launch.

The patched parser emits the function name after a validated invoke header,
then emits one fragment per completed top-level parameter and the final closing
brace. Nested parameter subtrees remain buffered until structurally complete;
this preserves typed conversion without building an XML-to-JSON chainsaw.
