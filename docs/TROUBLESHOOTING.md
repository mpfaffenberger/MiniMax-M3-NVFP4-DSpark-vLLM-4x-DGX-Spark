# Troubleshooting

## API never becomes healthy

```bash
./scripts/logs.sh
./scripts/status.sh
```

Look for the first traceback, not the final chorus of TP ranks reporting the
same failure. Model loading took roughly three minutes during validation.

## Multi-node launch hangs

Confirm all ranks use identical NCCL:

```bash
for host in $(tr ',' ' ' <<<"$CLUSTER_NODES"); do
  ssh "$host" "sha256sum ~/.cache/huggingface/hub/nccl-2.30.4/libnccl.so.2"
done
```

Then verify:

- both RoCE interfaces are up on every node;
- `ETH_IF` and `IB_IF` name real interfaces;
- head-to-worker SSH is noninteractive;
- firewall rules allow NCCL and `MASTER_PORT` traffic;
- no stale containers or vLLM rank processes remain from another deployment.

## OOM or host becomes unresponsive

Check kernel and container logs:

```bash
dmesg | grep -Ei 'oom|killed process|NVRM|NV_ERR'
docker logs "$CONTAINER_NAME" 2>&1 | grep -E 'quantization|ModelOpt|RuntimeError'
```

Do not remove `guard-minimax-m3-modelopt-fp4`. It exists specifically to turn a
silent BF16 allocation disaster into an immediate useful error.

## Tool parser is missing

An error mentioning `vllm._rust_tool_parser` means the mod was not installed or
its ABI does not match the runtime. Run `make validate`, then bootstrap again.
The included artifact is only for the documented arm64 Python 3.12 runtime.

## Raw `<mm:think>` appears in content

The adaptive-state patch is absent or did not match the vLLM source. Confirm
startup logs contain:

```text
[fix-minimax-m3-streaming-reasoning] adaptive, disabled, and enabled prompt-state checks passed
```

## Response contains `reasoning` instead of `reasoning_content`

Confirm startup logs contain serialization checks from
`rename-reasoning-to-reasoning-content`, then run `python3 scripts/smoke.py`.

## DSpark acceptance is low

Use `make metrics`. Acceptance depends on prompt shape, sampling, and generation
phase. A low token acceptance percentage is not automatically a broken setup;
the useful measurements are accepted tokens per draft and end-to-end decode
throughput. Compare repeated workloads with warm prefix cache, not one tiny
request against a cold server.

## Safe restart after a failed load

Stop the cluster first. If GB10 unified memory is not released after containers
exit, inspect processes before touching the NVIDIA driver. Driver cycling is a
host-level operation and should not be automated casually in a public script.
