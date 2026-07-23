#!/usr/bin/env bash
# Keep closed marker examples in the prompt from disabling adaptive streaming.
set -euo pipefail

readonly SITE_PACKAGES="$(python3 -c 'import site; print(site.getsitepackages()[0])')"
readonly PARSER_FILE="${SITE_PACKAGES}/vllm/reasoning/minimax_m3_reasoning_parser.py"
readonly MARKER="fix-minimax-m3-streaming-reasoning"

SOURCE_FILE="${PARSER_FILE}" PATCH_MARKER="${MARKER}" python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["SOURCE_FILE"])
marker = os.environ["PATCH_MARKER"]
text = path.read_text()

old_state = '''        chat_kwargs = kwargs.get("chat_template_kwargs", {}) or {}
        self._initial_in_reasoning = chat_kwargs.get("thinking_mode") == "enabled"
'''
new_state = '''        chat_kwargs = kwargs.get("chat_template_kwargs", {}) or {}
        # fix-minimax-m3-streaming-reasoning: preserve the explicit mode so
        # closed marker examples in the rendered prompt do not end adaptive
        # reasoning before generation starts.
        self._thinking_mode = chat_kwargs.get("thinking_mode")
        self._initial_in_reasoning = self._thinking_mode == "enabled"
'''

old_method = '''    def is_reasoning_end(self, input_ids: Sequence[int]) -> bool:
        start_index = self._rfind_token_sequence(input_ids, self._start_token_ids)
'''
new_method = '''    def is_reasoning_end(self, input_ids: Sequence[int]) -> bool:
        # The system instructions contain a closed <mm:think> example. In
        # adaptive mode that example describes the protocol; it does not mean
        # the new assistant turn has already finished reasoning.
        if self._thinking_mode == "disabled":
            return True
        if self._thinking_mode != "enabled":
            return False

        start_index = self._rfind_token_sequence(input_ids, self._start_token_ids)
'''

if marker in text:
    print(f"[{marker}] already applied; skipping")
else:
    if text.count(old_state) != 1:
        raise RuntimeError("expected exactly one MiniMax-M3 parser state block")
    if text.count(old_method) != 1:
        raise RuntimeError("expected exactly one MiniMax-M3 is_reasoning_end method")
    text = text.replace(old_state, new_state, 1)
    text = text.replace(old_method, new_method, 1)
    path.write_text(text)
    print(f"[{marker}] applied to {path}")
PY

python3 -m py_compile "${PARSER_FILE}"

python3 - <<'PY'
from vllm.reasoning.minimax_m3_reasoning_parser import MiniMaxM3ReasoningParser

class TokenizerStub:
    def __init__(self):
        self.vocab = {
            "<mm:think>": 1,
            "</mm:think>": 2,
        }

    def get_vocab(self):
        return self.vocab

    def encode(self, text, add_special_tokens=False):
        if text == "<mm:think>":
            return [1]
        if text == "</mm:think>":
            return [2]
        return [99]

    def decode(self, token_ids, skip_special_tokens=False):
        return "".join({1: "<mm:think>", 2: "</mm:think>"}.get(i, "x") for i in token_ids)

stub = TokenizerStub()
# The closed pair models marker examples embedded in system instructions.
adaptive = MiniMaxM3ReasoningParser(stub, chat_template_kwargs={})
assert adaptive.is_reasoning_end([1, 99, 2]) is False

disabled = MiniMaxM3ReasoningParser(
    stub, chat_template_kwargs={"thinking_mode": "disabled"}
)
assert disabled.is_reasoning_end([1, 99, 2]) is True

enabled = MiniMaxM3ReasoningParser(
    stub, chat_template_kwargs={"thinking_mode": "enabled"}
)
assert enabled.is_reasoning_end([1, 99, 2, 1]) is False
assert enabled.is_reasoning_end([1, 99, 2]) is True

print(
    "[fix-minimax-m3-streaming-reasoning] "
    "adaptive, disabled, and enabled prompt-state checks passed"
)
PY
