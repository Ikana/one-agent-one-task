---
name: one-agent-one-task
description: Scaffold a one-communicator, file-coordinated OpenClaw workspace with isolated worker agents.
user-invocable: true
disable-model-invocation: false
metadata:
  openclaw:
    requires:
      bins: ["docker", "jq"]
      os: linux
---

# one-agent-one-task

Use this skill when the user wants a disciplined OpenClaw multi-agent layout with one communicator agent and file-based worker coordination.

## Workflow

1. Inspect the current workspace for an existing scaffold before creating a new one.
2. Run `scripts/scaffold.sh <project-name>` with any requested `--agents`, `--coord-path`, or `--output-dir` overrides.
3. Point the user to `config/openclaw.json5`, `agents/`, `coord/`, and `docs/architecture.md`.
4. Recommend `scripts/smoke-test.sh` after scaffolding.
5. If the user is targeting a Raspberry Pi, use `scripts/bootstrap-pi.sh`.
6. If the user wants a Mac companion node, use `scripts/setup-mac-node.sh`.

## Guardrails

- Keep exactly one communicator agent.
- Route worker coordination through `/coord`, not agent chat.
- Give each agent a unique `agentDir`.
- Keep worker sandboxes isolated with `sandbox.scope: "agent"`.
- Bind only the coordination directory into worker sandboxes.

## Examples

```bash
./scripts/scaffold.sh my-project
./scripts/scaffold.sh my-project --agents "communicator,planner,coder,reviewer"
./scripts/smoke-test.sh my-project --skip-docker
```
