# Architecture Decisions

This project scaffolds an OpenClaw setup where one communicator owns every user-facing exchange and worker agents coordinate through files in a shared directory mounted at `/coord`.

## Supported decisions

- **One gateway**: the gateway remains the single control plane for channels, model calls, and tool execution.
- **One communicator**: only the communicator is bound to user-facing channels. Workers never message the user directly.
- **Per-agent sandboxes**: workers use `sandbox.scope: "agent"` so each role has a separate container lifecycle and unique `agentDir`.
- **Narrow shared mount**: the only shared host path is the coordination directory mounted at `/coord`.

## Practical conventions

- **File-first coordination**: tasks, results, signals, and status files are the system-of-record for worker handoffs.
- **`sessions_spawn` as control plane**: the communicator can trigger workers, but files remain the data plane.
- **Per-role templates**: each role gets an `AGENT.md` tuned to one responsibility.

## Tradeoffs

- **Latency vs simplicity**: files are slower than direct RPC, but they are inspectable, durable, and easy to debug.
- **Stateful sandboxes vs RAM**: per-agent containers preserve useful state, but memory limits need to stay conservative on a Raspberry Pi.
- **Explicit bindings vs convenience**: requiring one communicator reduces flexibility, but it also prevents accidental user-facing behavior from workers.

## Security model

- Worker sandboxes run with Docker isolation.
- Reviewer agents default to read-only workspace access.
- Worker tool lists deny user-facing message tools.
- Agent state directories are unique and never shared.

## Deployment posture

- Raspberry Pi is the primary target.
- Docker is the supported isolation mechanism.
- A Mac can be added as a companion node without introducing a second gateway.
