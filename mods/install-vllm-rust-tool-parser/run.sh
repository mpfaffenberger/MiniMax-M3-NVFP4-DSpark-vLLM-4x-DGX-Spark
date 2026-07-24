#!/usr/bin/env bash
# Install vLLM's MiniMax-M3 PyO3 tool-parser extension built from b44311b6.
set -euo pipefail

readonly EXPECTED_SHA256="346e6e0a64613c20decc0cf97bfcdd1a02b18b836d650e23097697c4a80af275"
readonly MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE="${MOD_DIR}/_rust_tool_parser.abi3.so"
readonly SITE_PACKAGES="$(python3 -c 'import site; print(site.getsitepackages()[0])')"
readonly DESTINATION="${SITE_PACKAGES}/vllm/_rust_tool_parser.abi3.so"

verify_sha256() {
    local path="$1"
    local actual
    actual="$(sha256sum "${path}" | awk '{print $1}')"
    if [[ "${actual}" != "${EXPECTED_SHA256}" ]]; then
        echo "[install-vllm-rust-tool-parser] checksum mismatch for ${path}" >&2
        echo "expected=${EXPECTED_SHA256}" >&2
        echo "actual=${actual}" >&2
        return 1
    fi
}

verify_sha256 "${SOURCE}"

if [[ -f "${DESTINATION}" ]] && [[ "$(sha256sum "${DESTINATION}" | awk '{print $1}')" == "${EXPECTED_SHA256}" ]]; then
    echo "[install-vllm-rust-tool-parser] already installed; skipping copy"
else
    install -m 0755 "${SOURCE}" "${DESTINATION}"
    echo "[install-vllm-rust-tool-parser] installed ${DESTINATION}"
fi

verify_sha256 "${DESTINATION}"

python3 - <<'PY'
import json
import vllm._rust_tool_parser as rust_parser

schema = {
    "type": "object",
    "properties": {
        "city": {"type": "string"},
        "units": {"type": "string"},
    },
    "required": ["city"],
}
tool = rust_parser.Tool("get_weather", "Get weather", schema, None)
parser = rust_parser.ToolParser("MinimaxM3ToolParser", [tool])
output = rust_parser.ToolParserOutput()
fixture = (
    "]<]minimax[>[<tool_call>\n"
    "]<]minimax[>[<invoke name=\"get_weather\">\n"
    "]<]minimax[>[<city>New York]<]minimax[>[</city>\n"
    "]<]minimax[>[<units>metric]<]minimax[>[</units>\n"
    "]<]minimax[>[</invoke>\n"
    "]<]minimax[>[</tool_call>"
)
stream_parser = rust_parser.ToolParser("MinimaxM3ToolParser", [tool])
streamed = []
for chunk in (
    "]<]minimax[>[<tool_call>\n"
    "]<]minimax[>[<invoke name=\"get_weather\">\n",
    "]<]minimax[>[<city>New ",
    "York]<]minimax[>[</city>\n",
    "]<]minimax[>[<units>metric]<]minimax[>[</units>\n",
    "]<]minimax[>[</invoke>\n]<]minimax[>[</tool_call>",
):
    chunk_output = rust_parser.ToolParserOutput()
    stream_parser.parse_into(chunk, chunk_output)
    streamed.extend((call.name, call.arguments) for call in chunk_output.calls)
stream_parser.finish()
assert streamed == [
    ("get_weather", ""),
    (None, '{"city":"'),
    (None, "New "),
    (None, "York"),
    (None, '"'),
    (None, ',"units":"'),
    (None, "metric"),
    (None, '"'),
    (None, "}"),
], streamed

parser.parse_into(fixture, output)
output.append(parser.finish())
parsed = output.coalesce()
assert parsed.normal_text == ""
assert len(parsed.calls) == 1
assert parsed.calls[0].name == "get_weather"
assert json.loads(parsed.calls[0].arguments) == {
    "city": "New York",
    "units": "metric",
}
print(
    "[install-vllm-rust-tool-parser] import, incremental streaming, and MiniMax parse checks passed"
)
PY
