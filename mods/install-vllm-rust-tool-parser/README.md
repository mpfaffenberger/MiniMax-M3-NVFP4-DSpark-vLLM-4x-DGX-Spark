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
  `346e6e0a64613c20decc0cf97bfcdd1a02b18b836d650e23097697c4a80af275`
- Incremental-streaming patch SHA-256:
  `116d7e69befe8204a7c54ef81fad823f1a32e70582d1d045bff786f2d92cd8a4`
- Scalar-string streaming patch SHA-256:
  `7745b940b7c06b29bb82a1f2976b543b51c83cd2b5959fbcf473fbfc898989cb`

The extension was built on an aarch64 DGX Spark host and tested inside
`vllm-node-tf5-minimax-m3-dspark-20260722`, matching production Python 3.12.
The `pyo3/extension-module` feature is required; without it, a direct Cargo
build incorrectly links a specific `libpython`.

## Build command

From an exact checkout of the vLLM commit:

```bash
git apply minimax-m3-incremental-streaming.patch
git apply minimax-m3-string-streaming-on-top.patch
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

The patched parser emits the function name after a validated invoke header.
Exact schema-typed top-level strings then stream as escaped JSON body fragments,
which keeps large `create_file.content` arguments moving continuously. Numbers,
booleans, nullable unions, arrays, objects, unknown fields, and nested XML remain
buffered until their top-level parameter is structurally complete. Whitespace,
quotes, backslashes, control characters, and Unicode string content are
preserved; MiniMax namespace marker prefixes are held back so closing tags never
leak into arguments.
