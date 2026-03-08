# Claude Brief: `one-agent-one-task`

## Goal
Design and scaffold an OpenClaw / ClawHub skill named **`one-agent-one-task`**.

The skill should help create a disciplined multi-agent architecture where:

1. **Exactly one communicator agent** is allowed to talk to the end user.
2. **All worker agents are sandboxed with Docker-backed execution**.
3. **Agents communicate through files, not through a chat bus**.
4. The only approved escape hatch is a file-based signal such as: **“hey, look at this file”**.
5. The implementation should prefer **well-maintained, officially recommended OpenClaw paths**.
6. The first deployment target is a **Raspberry Pi 5 Model B (4GB RAM, 4 cores)**, with optional extension to a **Mac node**.

## Product intent
This is meant to become a **ClawHub skill** that can:

- scaffold a practical one-agent-one-task project layout,
- generate the needed OpenClaw config and documentation,
- optionally generate bootstrap scripts for Raspberry Pi and Mac node setups,
- and make it easy to publish or sync the skill bundle to ClawHub.

## Non-negotiable principles

### 1) One communicator only
The communicator agent is the only agent allowed to:

- receive inbound user messages,
- produce final user-facing responses,
- summarize work from other agents,
- decide when to ask a user follow-up.

Worker agents must **never** directly message the user.

### 2) File-first coordination
All worker-to-worker and worker-to-communicator coordination should happen through a **shared filesystem contract**, not a conversational API.

Use a simple directory protocol such as:

- `coord/inbox/<agent>/`
- `coord/outbox/<agent>/`
- `coord/artifacts/`
- `coord/status/`
- `coord/locks/`
- `coord/signals/`

Workers should exchange structured files such as:

- `task.json`
- `result.json`
- `status.json`
- `README.md`
- `DIFF.patch`
- `ATTN.communicator`

The “escape hatch” should be explicit and narrow, for example:

- create `coord/signals/communicator/<ticket>.json`
- include `{ "reason": "review_artifact", "path": "coord/artifacts/..." }`

### 3) No agent chat bus
Do **not** design the worker layer around inter-agent chat APIs.
Do **not** rely on worker-to-worker conversation history as the main transport.
If OpenClaw session tools are used at all, they should be used only as **control-plane orchestration**, not as the data plane.

### 4) Strong isolation by default
Each worker should have:

- its own agent id,
- its own workspace,
- its own `agentDir`,
- its own sandbox/tool policy,
- its own limited responsibility.

### 5) Small, maintained, boring infrastructure
Prefer the most maintained OpenClaw paths over clever custom infrastructure.

## Facts to respect from current OpenClaw docs
Use these as constraints when designing:

1. OpenClaw generally prefers **one Gateway with many agents**, not many gateways on the same machine.
2. Multiple gateways are for stricter isolation or redundancy, not the default.
3. In OpenClaw, the **Gateway stays on the host**; Docker sandboxing applies to **tool execution**, not the gateway itself.
4. `sandbox.scope: "agent"` gives one container per agent.
5. `sandbox.docker.binds` can mount a shared host directory into sandboxes.
6. Bind mounts are powerful and risky, so keep the shared mount narrow.
7. `workspaceAccess: "rw"` mounts the workspace read/write; `"ro"` mounts it read-only; `"none"` keeps the sandbox on its own filesystem.
8. Each agent has a separate `agentDir` auth store; do not reuse them.
9. `sessions_spawn` can launch sub-agent runs; if used, child runs should not directly announce to the user.
10. OpenProse is available for explicit orchestration and reusable workflows.
11. ClawHub is the public registry for skills, and skills are standard folders with a `SKILL.md` file.
12. For production servers, the preferred deployment path is `openclaw-ansible`.
13. For Raspberry Pi, use the officially documented Pi install path.
14. For Mac integration, prefer node mode / node host rather than a second gateway unless there is a real trust-boundary reason.
15. Bun should not be the default gateway runtime.

## Recommended architecture to design
Propose the **smallest practical architecture** that matches the above principles.

### Core shape
- **One OpenClaw Gateway**.
- **One communicator agent** bound to the user-facing channel(s).
- **Several worker agents** with distinct roles, for example:
  - `planner`
  - `researcher`
  - `coder`
  - `reviewer`
  - `runner`

### Communication model
Preferred model:

- Communicator decides work.
- Communicator creates or updates task files in the shared coordination directory.
- A worker is triggered either by:
  - an explicit orchestrator action,
  - a polling script,
  - or a narrow helper wrapper.
- Worker reads its assigned files, performs work inside its sandbox, writes result files, and optionally writes a signal for communicator review.
- Communicator reads output files and produces the only user-facing message.

### Acceptable OpenClaw-native compromise
If a pure file-polling design becomes too awkward, use:

- `sessions_spawn` only to launch a worker task,
- require worker output to be written to files,
- require workers to suppress direct user announcements,
- and keep file artifacts as the source of truth.

### Shared filesystem policy
Use a **single narrow shared mount**, not a broad host mount.
Example intent:

- host path: `/var/lib/one-agent-one-task/coord`
- mount path in sandboxes: `/coord`

Avoid sharing secrets, home directories, SSH material, or Docker socket access.

## Deployment targets

### Target A: Raspberry Pi 5 (primary)
Design for:

- Raspberry Pi 5 Model B
- 4GB RAM
- 4 cores
- 64-bit Raspberry Pi OS Lite
- Node 22
- Docker available for sandboxes

The design should be conservative with RAM and avoid heavyweight defaults.

### Target B: Mac companion node (optional)
Add an optional path where:

- the Gateway stays on the Pi,
- a Mac connects as a node,
- Mac-only capabilities run through the node when needed.

Do not make the Mac a required part of the base design.

## What to produce
Produce the following deliverables.

### 1) Architecture brief
A concise design doc that explains:

- why one Gateway is preferred,
- why one communicator exists,
- why workers are file-coordinated,
- what the security model is,
- and what tradeoffs remain.

### 2) Skill bundle skeleton
Create a ClawHub-ready skill bundle with at least:

- `one-agent-one-task/SKILL.md`
- `one-agent-one-task/README.md`
- `one-agent-one-task/examples/`
- `one-agent-one-task/templates/`
- `one-agent-one-task/scripts/`

### 3) `SKILL.md`
Write a strong `SKILL.md` that teaches the agent to:

- scaffold the one-agent-one-task layout,
- generate coordination directories,
- generate an OpenClaw config template,
- generate agent role templates,
- generate a Raspberry Pi bootstrap path,
- optionally generate Mac node setup instructions,
- and avoid unsafe or unsupported shortcuts.

### 4) Config template
Generate a realistic example config that demonstrates:

- one communicator agent,
- multiple worker agents,
- per-agent tool restrictions,
- Docker sandboxing,
- `sandbox.scope: "agent"`,
- a shared coordination bind mount,
- bindings for the communicator only,
- and worker agents with no direct messaging role.

### 5) Bootstrap scripts
Generate scripts or script templates for:

- Pi bootstrap
- skill scaffold generation
- optional Mac node setup
- optional validation / smoke test

Keep scripts understandable and boring.

### 6) Publish workflow
Include the exact local workflow for:

- testing the skill locally,
- installing it into a workspace,
- publishing it to ClawHub,
- syncing updates later.

## Guardrails

1. Do not assume multiple gateways are the default answer.
2. Do not invent custom networking when an official OpenClaw path exists.
3. Do not use Bun as the default gateway runtime.
4. Do not make workers user-facing.
5. Do not reuse `agentDir` across agents.
6. Do not mount broad host paths into every sandbox.
7. Do not make the design depend on chat-style inter-agent APIs.
8. Do not overfit to cloud-first deployment when the primary target is the Pi.

## Design preferences

- Prefer **simple JSON/JSON5/YAML/Markdown** over bespoke binary formats.
- Prefer **explicit manifests** over hidden coordination state.
- Prefer **append-only logs** for debugging.
- Prefer **small shell scripts** over heavy background services.
- Prefer **official OpenClaw install/update flows**.
- Prefer **reproducible directory layouts**.

## Suggested initial agent roles
These are suggestions, not hard requirements.

### `communicator`
Responsibilities:
- own inbound/outbound user communication,
- decide delegation,
- read worker artifacts,
- produce the final answer.

Likely tool posture:
- may read coordination files,
- may orchestrate worker runs,
- must be the only user-facing agent.

### `planner`
Responsibilities:
- convert user goals into task manifests,
- break large work into file-based tickets.

### `researcher`
Responsibilities:
- gather and synthesize information into files,
- never answer the user directly.

### `coder`
Responsibilities:
- write implementation artifacts,
- update patches or files in assigned workspace areas.

### `reviewer`
Responsibilities:
- read artifacts,
- critique output,
- produce approval or rejection files.

### `runner`
Responsibilities:
- execute tests or controlled commands,
- write logs and structured outcomes.

## Acceptance criteria
A good answer will:

1. stay close to official OpenClaw primitives,
2. clearly separate control plane from data plane,
3. make the communicator the only user-facing agent,
4. use Docker sandboxing realistically,
5. show how the shared filesystem contract works,
6. fit within Raspberry Pi 5 4GB constraints,
7. offer an optional Mac node path,
8. and give a publishable ClawHub skill skeleton.

## Extra request
Where possible, explain whether each recommendation is:

- **officially supported**,
- **a practical convention**, or
- **a custom layer we are adding**.

Be opinionated, but keep the design operationally simple.
