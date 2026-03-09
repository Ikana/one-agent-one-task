# Research: One-Agent-One-Task

**Branch**: `001-one-agent-one-task` | **Date**: 2026-03-08

## R1: Project Language & Runtime

**Decision**: Bash (shell scripts) for all scaffolding and bootstrap tooling. JSON5 for config templates. Markdown for documentation templates.

**Rationale**: The tool generates files — it doesn't run a long-lived service. Shell scripts are the simplest, most portable option for a scaffolding tool targeting Raspberry Pi OS Lite (which ships with bash). No build step, no dependency installation for the tool itself. JSON5 is the native config format for OpenClaw's `openclaw.json`.

**Alternatives considered**:
- **Node.js CLI**: Would require Node as a dependency for the tool itself (not just the gateway). Adds unnecessary coupling.
- **Python CLI**: Extra runtime dependency on Pi. Overkill for file generation.
- **Go binary**: Fast, but adds a build/cross-compile step and doesn't match the "boring scripts" design preference.

## R2: OpenClaw Gateway Config Format

**Decision**: Use JSON5 format for the generated `openclaw.json` config template.

**Rationale**: OpenClaw's gateway config lives at `~/.openclaw/openclaw.json` and uses JSON5 (supports comments and trailing commas). The gateway does strict schema validation — unknown keys or invalid values cause startup failure. Config supports `$include` directives for splitting into multiple files, and hot-reloads most settings.

**Key config structure for our use case**:
```json5
{
  gateway: { ... },
  agents: {
    defaults: {
      sandbox: {
        mode: "non-main",
        scope: "agent",
        docker: { image, memory, cpus, binds, ... }
      }
    },
    list: [
      { id, workspace, agentDir, ... }
    ]
  }
}
```

**Alternatives considered**:
- **YAML config**: Not supported by OpenClaw — must be JSON5.
- **Config generator in JS**: Overengineered — a static JSON5 template with sed/envsubst replacements is sufficient.

## R3: Docker Sandbox Strategy

**Decision**: Use `sandbox.scope: "agent"` with per-agent memory limits and a narrow shared bind mount at `/coord`.

**Rationale**: `scope: "agent"` gives each agent its own persistent container that survives across sessions. This matches the one-agent-one-task model: each worker has its own isolated environment. The container reuse means installed packages and cloned repos persist between runs, reducing setup overhead on constrained hardware.

**Sandbox settings**:
- `sandbox.mode: "non-main"` — sandbox worker sessions, not the communicator's main session
- `sandbox.scope: "agent"` — one container per agent
- `sandbox.workspaceAccess: "rw"` for agents that need to write code; `"ro"` for reviewers
- `sandbox.docker.memory: "384m"` — conservative for Pi 5 (6 agents × 384MB > 4GB, but not all run simultaneously)
- `sandbox.docker.cpus: 1` — one core per active sandbox
- `sandbox.docker.binds: ["/var/lib/one-agent-one-task/coord:/coord:rw"]` — shared coordination mount
- `sandbox.docker.network: "none"` for workers that don't need network; researcher may need network access

**Important**: `docker.binds` paths must not overlap with `/workspace` (known OpenClaw issue #22669). The `/coord` mount path is safe.

**Alternatives considered**:
- `scope: "session"` — creates new containers per session, losing state. Bad for Pi performance.
- `scope: "shared"` — single container for all agents, breaks isolation principle.
- No sandboxing — violates the strong isolation requirement.

## R4: Agent-to-Agent Communication Model

**Decision**: File-based coordination through a shared `/coord` directory, with `sessions_spawn` as the control-plane trigger.

**Rationale**: The brief explicitly requires file-first coordination and no chat bus. OpenClaw's `sessions_spawn` tool can launch sub-agent runs, but the data exchange happens through files, not through the session return value. Workers read from `coord/inbox/<agent>/`, write to `coord/outbox/<agent>/`, and signal the communicator via `coord/signals/communicator/`.

**Communication flow**:
1. Communicator writes `task.json` to `coord/inbox/<worker>/`
2. Communicator calls `sessions_spawn` with a task instruction pointing at the file
3. Worker reads `task.json`, does work, writes `result.json` to `coord/outbox/<worker>/`
4. Worker optionally writes signal file to `coord/signals/communicator/`
5. Communicator reads result files and produces user-facing response

**Why `sessions_spawn` and not polling**:
- Pure file-polling requires a background daemon or cron job — adds infrastructure
- `sessions_spawn` is the officially supported way to launch sub-agent work
- The sub-agent result is a run ID (non-blocking), and the communicator can poll result files
- This keeps `sessions_spawn` as control plane only — data stays in files

**Alternatives considered**:
- Pure file polling with a shell loop — too fragile, adds a daemon
- OpenProse workflows — interesting but adds a learning curve; better as a Phase 2 enhancement
- `agentToAgent.enabled: true` — known to have bugs with sub-agent startup (issue #5813)

## R5: ClawHub Skill Bundle Structure

**Decision**: Package as a ClawHub skill with `SKILL.md` frontmatter, scaffold scripts, and template files.

**Rationale**: ClawHub is the official skill registry. Skills are directories with a `SKILL.md` (YAML frontmatter + markdown instructions). The `clawhub publish` CLI handles versioning and distribution.

**Skill structure**:
```
one-agent-one-task/
├── SKILL.md              # Skill definition with frontmatter
├── README.md             # Human-readable documentation
├── examples/             # Example configs and layouts
├── templates/            # JSON5 config templates, file templates
├── scripts/              # Scaffold, bootstrap, smoke test scripts
└── docs/                 # Architecture brief, deployment guides
```

**SKILL.md frontmatter**:
```yaml
---
name: one-agent-one-task
description: Scaffold a disciplined multi-agent architecture with one communicator and file-coordinated workers.
user-invocable: true
disable-model-invocation: false
metadata:
  openclaw:
    requires:
      bins: ["docker", "jq"]
      os: linux
---
```

**Alternatives considered**:
- Standalone npm package — doesn't integrate with the OpenClaw skill ecosystem
- Git submodule — harder to discover and install than a ClawHub skill

## R6: Raspberry Pi Deployment Path

**Decision**: Use the official OpenClaw install script plus a custom post-install bootstrap that sets up coordination directories and the multi-agent config.

**Rationale**: The official Pi path is `curl -fsSL https://openclaw.ai/install.sh | bash`, which handles Node.js, the gateway, and systemd service setup. Our bootstrap script adds the one-agent-one-task layer on top: creating `/var/lib/one-agent-one-task/coord`, generating the multi-agent `openclaw.json`, and setting memory limits appropriate for 4GB RAM.

**Pi-specific optimizations**:
- USB SSD recommended (docs say "dramatically better I/O")
- Enable Node compile cache: `NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache`
- Add 2GB swap for stability
- Use cloud-based models (Claude, GPT-4) — not local LLMs
- `sandbox.docker.memory: "384m"` per agent — conservative for 4GB total

**Alternatives considered**:
- `openclaw-ansible` — designed for Debian/Ubuntu servers with Tailscale; heavier than needed for a Pi home setup
- Manual install guide — error-prone, the install script is simpler

## R7: Mac Companion Node

**Decision**: Use OpenClaw's native node mode — Mac connects as a node to the Pi gateway via WebSocket.

**Rationale**: Nodes are officially supported companion devices. The Mac menubar app connects to the gateway's WebSocket and exposes local commands (`canvas.*`, `camera.*`, `system.run`). The gateway stays on the Pi; the Mac extends capability without becoming a second gateway.

**Setup flow**:
1. Install OpenClaw menubar app on Mac
2. Point it at the Pi gateway's Tailscale/local IP
3. Approve the node pairing on the Pi: `openclaw devices approve <requestId>`
4. Configure agents that need Mac-only tools to route through the node

**Alternatives considered**:
- Second gateway on Mac — violates the "one gateway" principle; adds complexity
- SSH-based remote execution — fragile, no official support
- Docker context sharing — doesn't work cross-architecture (ARM Pi → x86 Mac)

## R8: OpenProse Integration

**Decision**: Defer OpenProse to a future enhancement. Not in the initial skill.

**Rationale**: OpenProse (`.prose` workflow files) could orchestrate the communicator→worker dispatch elegantly, but it adds a learning curve and a dependency on the `open-prose` plugin. The initial version should use `sessions_spawn` + files, which requires zero additional plugins. OpenProse can be layered on top later as an optional enhancement.

**Alternatives considered**:
- Ship with OpenProse workflows from day one — premature complexity
- Replace `sessions_spawn` with OpenProse entirely — loses the "boring infrastructure" preference
