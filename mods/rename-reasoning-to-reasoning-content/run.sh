#!/usr/bin/env bash
# Rename Chat Completions response field `reasoning` to `reasoning_content`.
set -euo pipefail

readonly SITE_PACKAGES="$(python3 -c 'import site; print(site.getsitepackages()[0])')"
readonly CHAT_PROTOCOL="${SITE_PACKAGES}/vllm/entrypoints/openai/chat_completion/protocol.py"
readonly ENGINE_PROTOCOL="${SITE_PACKAGES}/vllm/entrypoints/openai/engine/protocol.py"
readonly MARKER="rename-reasoning-to-reasoning-content"

patch_serializer() {
    local path="$1"
    local class_name="$2"
    FILE_PATH="${path}" CLASS_NAME="${class_name}" PATCH_MARKER="${MARKER}" python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["FILE_PATH"])
class_name = os.environ["CLASS_NAME"]
marker = os.environ["PATCH_MARKER"]
text = path.read_text()

insertion = '''        # rename-reasoning-to-reasoning-content: client compatibility.
        if "reasoning" in data:
            data["reasoning_content"] = data.pop("reasoning")
'''

if insertion in text:
    print(f"[{marker}] already applied to {path.name}; skipping")
else:
    class_start = text.index(f"class {class_name}(")
    serializer_start = text.index('    @model_serializer(mode="wrap")', class_start)
    handler_line = text.index("        data = handler(self)\n", serializer_start)
    insertion_at = handler_line + len("        data = handler(self)\n")
    text = text[:insertion_at] + insertion + text[insertion_at:]
    path.write_text(text)
    print(f"[{marker}] applied to {path}")
PY
}

patch_serializer "${CHAT_PROTOCOL}" "ChatMessage"
patch_serializer "${ENGINE_PROTOCOL}" "DeltaMessage"

python3 -m py_compile "${CHAT_PROTOCOL}" "${ENGINE_PROTOCOL}"

python3 - <<'PY'
import json

from vllm.entrypoints.openai.chat_completion.protocol import ChatMessage
from vllm.entrypoints.openai.engine.protocol import DeltaMessage

message = ChatMessage(role="assistant", reasoning="full reasoning", content="answer")
message_json = json.loads(message.model_dump_json(exclude_unset=True))
assert message_json == {
    "role": "assistant",
    "content": "answer",
    "reasoning_content": "full reasoning",
}
assert "reasoning" not in message_json

delta = DeltaMessage(reasoning="streamed reasoning")
delta_json = json.loads(delta.model_dump_json(exclude_unset=True))
assert delta_json == {"reasoning_content": "streamed reasoning"}
assert "reasoning" not in delta_json

print(
    "[rename-reasoning-to-reasoning-content] "
    "non-streaming and streaming serialization checks passed"
)
PY
