#!/usr/bin/env python3
"""Summarize live vLLM DSpark acceptance and decode throughput."""
from __future__ import annotations

import os
import re
import subprocess
import urllib.request
from dataclasses import dataclass


@dataclass(frozen=True)
class Metrics:
    drafts: float
    drafted_tokens: float
    accepted_tokens: float
    generated_tokens: float
    decode_seconds: float
    successful_requests: float


def env_file() -> dict[str, str]:
    result = dict(os.environ)
    path = os.environ.get("ENV_FILE", os.path.join(os.path.dirname(__file__), "..", ".env"))
    if not os.path.exists(path):
        return result
    for raw in open(path, encoding="utf-8"):
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        result.setdefault(key, value.strip().strip('"').strip("'"))
    return result


def value(text: str, metric: str, labels: str = "") -> float:
    pattern = rf"^{re.escape(metric)}\{{[^}}]*{labels}[^}}]*\}}\s+([0-9.eE+-]+)$"
    matches = re.findall(pattern, text, re.MULTILINE)
    return sum(map(float, matches))


def fetch(base: str) -> str:
    with urllib.request.urlopen(f"{base}/metrics", timeout=5) as response:
        return response.read().decode()


def collect(text: str) -> Metrics:
    return Metrics(
        drafts=value(text, "vllm:spec_decode_num_drafts_total"),
        drafted_tokens=value(text, "vllm:spec_decode_num_draft_tokens_total"),
        accepted_tokens=value(text, "vllm:spec_decode_num_accepted_tokens_total"),
        generated_tokens=value(text, "vllm:generation_tokens_total"),
        decode_seconds=value(text, "vllm:request_decode_time_seconds_sum"),
        successful_requests=value(text, "vllm:request_success_total", 'finished_reason="stop"'),
    )


def ratio(numerator: float, denominator: float) -> float:
    return numerator / denominator if denominator else 0.0


def recent_windows(container: str) -> list[tuple[str, str, str]]:
    command = ["docker", "logs", "--since", "30m", container]
    logs = subprocess.run(command, capture_output=True, text=True, check=False)
    text = logs.stdout + logs.stderr
    pattern = re.compile(
        r"(\d\d:\d\d:\d\d).*?Mean acceptance length: ([0-9.]+),.*?"
        r"Accepted throughput: ([0-9.]+) tokens/s"
    )
    return pattern.findall(text)[-8:]


def main() -> None:
    env = env_file()
    head = env.get("CLUSTER_NODES", "127.0.0.1").split(",")[0]
    port = env.get("API_PORT", "8000")
    base = os.environ.get("VLLM_BASE_URL", f"http://{head}:{port}")
    metrics = collect(fetch(base))

    print("DSpark cumulative")
    print(f"  drafts:                  {metrics.drafts:,.0f}")
    print(f"  drafted tokens:          {metrics.drafted_tokens:,.0f}")
    print(f"  accepted tokens:         {metrics.accepted_tokens:,.0f}")
    print(f"  token acceptance:        {ratio(metrics.accepted_tokens, metrics.drafted_tokens):.1%}")
    print(f"  accepted tokens/draft:   {ratio(metrics.accepted_tokens, metrics.drafts):.2f}")
    print(f"  generated tokens:        {metrics.generated_tokens:,.0f}")
    print(f"  aggregate decode speed:  {ratio(metrics.generated_tokens, metrics.decode_seconds):.1f} tok/s")
    print(f"  successful requests:     {metrics.successful_requests:,.0f}")

    windows = recent_windows(env.get("CONTAINER_NAME", "minimax_m3_dspark"))
    if windows:
        print("\nRecent 10s windows")
        for timestamp, length, accepted in windows:
            print(f"  {timestamp}  mean accepted={float(length):.2f}  accepted={float(accepted):.2f} tok/s")


if __name__ == "__main__":
    main()
