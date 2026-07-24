#!/usr/bin/env python3
"""Exercise MiniMax reasoning, streaming, disabled mode, and tool calling."""
from __future__ import annotations

import json
import os
import urllib.request
from typing import Any

MODEL = "nvidia/MiniMax-M3-NVFP4"


def load_env() -> dict[str, str]:
    env = dict(os.environ)
    path = os.environ.get("ENV_FILE", os.path.join(os.path.dirname(__file__), "..", ".env"))
    if os.path.exists(path):
        for raw in open(path, encoding="utf-8"):
            line = raw.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                env.setdefault(key, value.strip().strip('"').strip("'"))
    return env


def request(url: str, payload: dict[str, Any]) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=300) as response:
        return json.load(response)


def stream_message(url: str, payload: dict[str, Any]) -> tuple[str, str]:
    payload["stream"] = True
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    reasoning: list[str] = []
    content: list[str] = []
    with urllib.request.urlopen(req, timeout=300) as response:
        for raw in response:
            line = raw.decode().strip()
            if not line.startswith("data: ") or line == "data: [DONE]":
                continue
            delta = json.loads(line[6:])["choices"][0]["delta"]
            assert "reasoning" not in delta, delta
            reasoning.append(delta.get("reasoning_content") or "")
            content.append(delta.get("content") or "")
    return "".join(reasoning), "".join(content)


def stream_tool_call(
    url: str, payload: dict[str, Any]
) -> tuple[str, str, list[str], str | None]:
    """Collect one streamed tool name and its ordered argument fragments."""
    payload["stream"] = True
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    name = ""
    call_id = ""
    fragments: list[str] = []
    finish_reason = None
    with urllib.request.urlopen(req, timeout=300) as response:
        for raw in response:
            line = raw.decode().strip()
            if not line.startswith("data: ") or line == "data: [DONE]":
                continue
            choice = json.loads(line[6:])["choices"][0]
            finish_reason = choice.get("finish_reason") or finish_reason
            for call in choice["delta"].get("tool_calls") or []:
                call_id = call.get("id") or call_id
                function = call.get("function") or {}
                name = function.get("name") or name
                if function.get("arguments") is not None:
                    fragments.append(function["arguments"])
    return call_id, name, fragments, finish_reason


def message(url: str, **overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "model": MODEL,
        "messages": [{"role": "user", "content": "What is 12 + 30? Reply briefly."}],
        "temperature": 0,
        "max_tokens": 128,
    }
    payload.update(overrides)
    return request(url, payload)["choices"][0]["message"]


def main() -> None:
    env = load_env()
    head = env.get("CLUSTER_NODES", "127.0.0.1").split(",")[0]
    port = env.get("API_PORT", "8000")
    url = os.environ.get("CHAT_URL", f"http://{head}:{port}/v1/chat/completions")

    normal = message(url)
    assert "reasoning" not in normal, normal
    assert normal.get("reasoning_content"), normal
    assert "<mm:think>" not in (normal.get("content") or ""), normal
    print("PASS reasoning_content compatibility")

    streamed_reasoning, streamed_content = stream_message(
        url,
        {
            "model": MODEL,
            "messages": [{"role": "user", "content": "What is 12 + 30? Reply briefly."}],
            "temperature": 0,
            "max_tokens": 128,
        },
    )
    assert streamed_reasoning, (streamed_reasoning, streamed_content)
    assert "<mm:think>" not in streamed_content, streamed_content
    assert "42" in streamed_content, streamed_content
    print("PASS adaptive SSE reasoning")

    disabled = message(
        url,
        messages=[{"role": "user", "content": "Reply with exactly: disabled clean"}],
        chat_template_kwargs={"thinking_mode": "disabled"},
        max_tokens=32,
    )
    assert disabled.get("content") == "disabled clean", disabled
    assert "reasoning" not in disabled, disabled
    assert not disabled.get("reasoning_content"), disabled
    print("PASS disabled thinking mode")

    tool = {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather",
            "parameters": {
                "type": "object",
                "properties": {"city": {"type": "string"}, "units": {"type": "string"}},
                "required": ["city", "units"],
            },
        },
    }
    called = message(
        url,
        messages=[{"role": "user", "content": "Use get_weather for Paris, France in metric units."}],
        tools=[tool],
        tool_choice="auto",
        max_tokens=256,
    )
    calls = called.get("tool_calls") or []
    assert calls and calls[0]["function"]["name"] == "get_weather", called
    arguments = json.loads(calls[0]["function"]["arguments"])
    assert arguments["city"] == "Paris, France" and arguments["units"] == "metric", arguments
    print("PASS typed MiniMax tool call")

    call_id, name, fragments, finish_reason = stream_tool_call(
        url,
        {
            "model": MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": "Use get_weather for Paris, France in metric units.",
                }
            ],
            "tools": [tool],
            "tool_choice": "auto",
            "temperature": 0,
            "max_tokens": 256,
        },
    )
    assert call_id and name == "get_weather", (call_id, name, fragments)
    assert len(fragments) >= 6, fragments
    streamed_arguments = json.loads("".join(fragments))
    assert streamed_arguments["city"] == "Paris, France", streamed_arguments
    assert streamed_arguments["units"] == "metric", streamed_arguments
    assert finish_reason == "tool_calls", finish_reason
    print(f"PASS incremental MiniMax tool stream ({len(fragments)} argument deltas)")


if __name__ == "__main__":
    main()
