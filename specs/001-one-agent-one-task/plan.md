# Implementation Plan: One-Agent-One-Task

**Branch**: `001-one-agent-one-task` | **Date**: 2026-03-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-one-agent-one-task/spec.md`

## Summary

Build a ClawHub skill that scaffolds a disciplined multi-agent architecture for OpenClaw. The tool generates a complete project layout with one communicator agent (user-facing), multiple Docker-sandboxed worker agents, and a file-based coordination protocol. All scaffolding is done through bash scripts that produce JSON5 gateway configs, agent role templates, coordination directory structures, and deployment scripts targeting Raspberry Pi 5 as the primary platform.

## Technical Context

**Language/Version**: Bash (POSIX-compatible shell scripts), JSON5 for config templates, Markdown for docs
**Primary Dependencies**: OpenClaw gateway (Node.js 22), Docker, jq (for JSON validation in scripts)
**Storage**: Filesystem — JSON files for coordination, JSON5 for config, Markdown for docs
**Testing**: Shell-based smoke test scripts (`smoke-test.sh`), manual validation via `openclaw doctor`
**Target Platform**: Raspberry Pi 5 (4GB RAM, 64-bit Pi OS Lite) primary; macOS companion node optional
**Project Type**: CLI tool / ClawHub skill bundle
**Performance Goals**: Scaffold in <30s, idle gateway <512MB RAM on Pi
**Constraints**: 4GB RAM total on Pi, conservative memory per sandbox (384MB), 4 cores
**Scale/Scope**: Single gateway, ~6 default agents, single coordination directory

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Status**: Constitution file has not been filled out yet (still template placeholders). No gates to enforce. Proceeding without violations.

**Post-Phase-1 re-check**: Still no constitution defined. The design follows the brief's own guardrails as a substitute:
- ✅ One gateway only (no multi-gateway)
- ✅ One communicator only (enforced in config)
- ✅ File-first coordination (no chat bus)
- ✅ Docker sandboxing (scope: agent)
- ✅ No broad host mounts
- ✅ No Bun as gateway runtime
- ✅ Unique agentDir per agent
- ✅ Pi-first design (not cloud-first)

## Project Structure

### Documentation (this feature)

```text
specs/001-one-agent-one-task/
├── plan.md              # This file
├── research.md          # Phase 0 output — technology decisions
├── data-model.md        # Phase 1 output — entity definitions
├── quickstart.md        # Phase 1 output — getting started guide
├── contracts/
│   └── cli-interface.md # Phase 1 output — script and file contracts
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
one-agent-one-task/
├── SKILL.md                        # ClawHub skill definition (YAML frontmatter + instructions)
├── README.md                       # Human-readable project documentation
├── LICENSE                         # MIT license
│
├── scripts/
│   ├── scaffold.sh                 # Main scaffolding script
│   ├── bootstrap-pi.sh             # Raspberry Pi bootstrap script
│   ├── smoke-test.sh               # Validation / smoke test script
│   └── setup-mac-node.sh           # Optional Mac companion node setup
│
├── templates/
│   ├── config/
│   │   └── openclaw.json5          # Gateway config template (JSON5)
│   ├── agents/
│   │   ├── communicator.md         # Communicator agent role template
│   │   ├── planner.md              # Planner agent role template
│   │   ├── researcher.md           # Researcher agent role template
│   │   ├── coder.md                # Coder agent role template
│   │   ├── reviewer.md             # Reviewer agent role template
│   │   └── runner.md               # Runner agent role template
│   └── coordination/
│       ├── task.json               # Task file template
│       ├── result.json             # Result file template
│       ├── signal.json             # Signal file template
│       └── status.json             # Status file template
│
├── examples/
│   ├── minimal/                    # Minimal 3-agent example
│   │   ├── openclaw.json5
│   │   └── README.md
│   └── full/                       # Full 6-agent example
│       ├── openclaw.json5
│       └── README.md
│
├── docs/
│   ├── brief.md                    # Original design brief
│   └── architecture.md             # Architecture decision record
│
└── tests/
    ├── test-scaffold.sh            # Tests for scaffold.sh
    └── test-smoke.sh               # Tests for smoke-test.sh
```

**Structure Decision**: Single flat project — no src/ hierarchy needed. This is a skill bundle of shell scripts, templates, and documentation. The scripts generate projects; they are not a compiled application. The structure follows ClawHub skill conventions (SKILL.md at root, supporting directories underneath).

## Complexity Tracking

No constitution violations to justify — the design stays within all guardrails from the brief.

---

## Implementation Phases

### Phase A: Core Scaffolding (P1 stories)

**Goal**: `scaffold.sh` produces a valid project layout from a single command.

1. **Write `scaffold.sh`** — the main entry point
   - Parse CLI args (project name, --agents, --coord-path, --output-dir, --force, --json)
   - Create directory tree: `config/`, `agents/`, `templates/coordination/`, `scripts/`, `docs/`
   - Create coordination directory tree: `coord/inbox/<agent>/`, `coord/outbox/<agent>/`, `coord/artifacts/`, `coord/status/`, `coord/locks/`, `coord/signals/communicator/`
   - Copy and fill agent role templates for each specified agent
   - Generate `openclaw.json5` from the config template with per-agent settings
   - Copy bootstrap and smoke test scripts into the project
   - Generate project README.md

2. **Write config template `templates/config/openclaw.json5`**
   - One communicator agent with user-facing channel bindings
   - Worker agents with `sandbox.scope: "agent"`, `sandbox.mode: "non-main"`
   - Per-agent `agentDir` (unique paths)
   - Shared bind mount: `<coord-host-path>:/coord:rw`
   - Per-agent memory limits (384m default)
   - Per-agent tool restrictions (workers: no user messaging)
   - Placeholder sections for LLM provider config

3. **Write agent role templates** (`templates/agents/*.md`)
   - Each template defines the agent's role, responsibilities, and constraints
   - Communicator template includes: delegation logic, result reading, user response formatting
   - Worker templates include: task file reading, result file writing, signal creation
   - All workers include explicit instruction: "Never message the user directly"

4. **Write coordination file templates** (`templates/coordination/*.json`)
   - `task.json`, `result.json`, `signal.json`, `status.json`
   - Each with all fields, sensible defaults, and inline comments

### Phase B: Validation & Testing (P2 stories)

5. **Write `smoke-test.sh`**
   - Check directory structure completeness
   - Validate JSON5 config syntax (via `openclaw config show` or jq fallback)
   - Verify all agentDirs are unique
   - Check coordination directory permissions (read/write from current user)
   - Check Docker availability
   - Test bind mount accessibility (create temp file in coord, verify from sandbox perspective)
   - Output pass/fail summary (text and --json modes)
   - Write results to `coord/status/smoke-test.json`

6. **Write `bootstrap-pi.sh`**
   - Detect platform (fail if not arm64 Linux, warn on non-Pi)
   - Install Node 22 via NodeSource if not present
   - Install Docker via official convenience script if not present
   - Create swap file (default 2GB)
   - Create coordination host directory with correct permissions
   - Enable Node compile cache env var
   - Print post-install instructions

### Phase C: Documentation & Skill Bundle (P1/P2)

7. **Write `SKILL.md`**
   - YAML frontmatter: name, description, requires (bins: docker, jq), os: linux
   - Markdown body: instructions for scaffolding, configuration, and deployment
   - Include slash command integration

8. **Write `docs/architecture.md`**
   - Why one gateway (official OpenClaw recommendation)
   - Why one communicator (control plane / data plane separation)
   - Why file-coordinated workers (explicit, debuggable, append-only)
   - Security model (sandbox isolation, narrow mounts, unique agentDirs)
   - Tradeoffs (latency vs simplicity, sessions_spawn as control plane)

9. **Write example configs** (`examples/minimal/`, `examples/full/`)
   - Minimal: communicator + 2 workers
   - Full: communicator + 5 workers with all settings

### Phase D: Optional Mac Node (P3)

10. **Write `setup-mac-node.sh`**
    - Check for OpenClaw menubar app on Mac
    - Connect to Pi gateway via provided host/port
    - Trigger pairing and print approval instructions
    - Verify node connectivity

### Phase E: Tests

11. **Write `tests/test-scaffold.sh`**
    - Run scaffold in temp directory, verify output tree
    - Run scaffold with custom agents, verify custom dirs
    - Run scaffold with --force on existing dir
    - Validate all generated JSON is parseable

12. **Write `tests/test-smoke.sh`**
    - Run smoke test on valid project (expect pass)
    - Run smoke test on broken project (expect specific failures)

---

## Key Design Decisions

| Decision | Choice | Type | Rationale |
|----------|--------|------|-----------|
| Config format | JSON5 | **Officially supported** | OpenClaw's native config format |
| Sandbox scope | `agent` | **Officially supported** | One container per agent, persists across sessions |
| Shared mount | Single bind at `/coord` | **Practical convention** | Narrow mount per brief's security requirements |
| Worker dispatch | `sessions_spawn` | **Officially supported** | Native sub-agent launcher, non-blocking |
| Data exchange | Files in `/coord` | **Custom layer** | The file protocol is our design; OpenClaw provides the mount |
| Memory limit | 384MB per agent | **Custom layer** | Conservative for Pi 5 4GB; not all agents run simultaneously |
| Skill format | SKILL.md + bundle | **Officially supported** | Standard ClawHub skill format |
| Pi install | Official install script | **Officially supported** | `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| Mac node | Node mode via menubar app | **Officially supported** | Official companion device pattern |
| Agent instructions | Markdown AGENT.md files | **Practical convention** | Readable, editable, version-controllable |
| Orchestration | sessions_spawn (not OpenProse) | **Officially supported** | Simpler; OpenProse deferred to future enhancement |
