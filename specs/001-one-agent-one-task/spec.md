# Feature Specification: One-Agent-One-Task Multi-Agent Architecture Tool

**Feature Branch**: `001-one-agent-one-task`
**Created**: 2026-03-08
**Status**: Draft
**Input**: User description: "Scaffold the one-agent-one-task multi-agent architecture tool — a disciplined multi-agent system where exactly one communicator agent talks to the user, all worker agents run in Docker-backed sandboxes, and agents communicate through files, not chat."

> **Inspiration**: This project was inspired by [*10 OpenClaw Lessons for Building Agent Teams*](https://podcasts.apple.com/us/podcast/the-ai-daily-brief-artificial-intelligence-news/id1680633614) — a March 8, 2026 episode of Nathaniel Whittemore's *AI Daily Brief* podcast. The episode distills practical lessons from early OpenClaw builders about deliberate agent architecture: task separation, file-based orchestration, security boundaries, and cost-aware design. One-agent-one-task takes these lessons and encodes them into a repeatable scaffold.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Scaffold a New Project (Priority: P1)

A developer wants to start a new multi-agent project on their Raspberry Pi 5. They run the scaffolding tool, which creates the full directory layout: coordination directories, agent role templates, an OpenClaw gateway config, and bootstrap scripts. The developer ends up with a working project skeleton they can immediately configure and deploy.

**Why this priority**: This is the core value proposition — without scaffolding, everything else is manual setup.

**Independent Test**: Can be fully tested by running the scaffold command in an empty directory and verifying the output tree matches the expected layout with all required files present.

**Acceptance Scenarios**:

1. **Given** an empty directory, **When** the user runs the scaffold command, **Then** the tool creates the complete project layout including `coord/` subdirectories, agent role templates, gateway config, and bootstrap scripts.
2. **Given** an empty directory, **When** the user runs the scaffold command, **Then** every generated file is valid (JSON parses, shell scripts have correct shebangs, markdown renders properly).
3. **Given** a non-empty directory, **When** the user runs the scaffold command, **Then** the tool warns about existing files and asks for confirmation before overwriting.

---

### User Story 2 — Configure Agent Roles (Priority: P1)

A developer wants to customize which worker agents exist in their project. They can add, remove, or rename agent roles beyond the defaults (planner, researcher, coder, reviewer, runner). Each agent gets its own workspace, config section, and coordination directories.

**Why this priority**: Every project has different needs — rigid role sets would limit adoption.

**Independent Test**: Can be tested by running the scaffold with a custom agent list and verifying each agent has its own directory, config entry, and coordination paths.

**Acceptance Scenarios**:

1. **Given** a scaffold command with custom agent roles specified, **When** the tool runs, **Then** coordination directories are created for each specified agent (`coord/inbox/<agent>/`, `coord/outbox/<agent>/`).
2. **Given** a scaffolded project, **When** the user adds a new agent role, **Then** the tool creates all necessary directories and updates the gateway config to include the new agent.
3. **Given** a scaffold command with no custom roles, **When** the tool runs, **Then** it uses the default set: communicator, planner, researcher, coder, reviewer, runner.

---

### User Story 3 — Generate OpenClaw Gateway Config (Priority: P1)

A developer needs a working OpenClaw gateway configuration that enforces the one-communicator pattern. The generated config includes per-agent sandbox settings, tool restrictions, shared bind mounts for the coordination directory, and ensures only the communicator agent is user-facing.

**Why this priority**: The gateway config is the enforcement mechanism for every architectural principle — without it, the rules are just suggestions.

**Independent Test**: Can be tested by validating the generated config against the OpenClaw config schema and checking that only the communicator has user-facing channel bindings.

**Acceptance Scenarios**:

1. **Given** a scaffolded project, **When** the user inspects the generated gateway config, **Then** exactly one agent (communicator) is bound to user-facing channels.
2. **Given** a scaffolded project, **When** the user inspects the generated gateway config, **Then** each worker agent has `sandbox.scope: "agent"` with Docker isolation.
3. **Given** a scaffolded project, **When** the user inspects the generated gateway config, **Then** all sandboxes mount the coordination directory at `/coord` via a narrow bind mount, and no broader host paths are exposed.
4. **Given** a scaffolded project, **When** the user inspects the generated gateway config, **Then** each agent has a unique `agentDir` — none are shared.

---

### User Story 4 — Bootstrap a Raspberry Pi 5 Deployment (Priority: P2)

A developer wants to deploy their multi-agent project to a Raspberry Pi 5 with 4GB RAM. They run a bootstrap script that installs prerequisites (Node 22, Docker), configures the coordination directory on the host, and starts the gateway with conservative resource settings appropriate for constrained hardware.

**Why this priority**: The Pi is the primary deployment target, but scaffolding must work first.

**Independent Test**: Can be tested by running the bootstrap script on a clean Raspberry Pi OS Lite image and verifying that all prerequisites are installed and the gateway starts successfully.

**Acceptance Scenarios**:

1. **Given** a clean Raspberry Pi 5 with 64-bit Pi OS Lite, **When** the user runs the Pi bootstrap script, **Then** Node 22 and Docker are installed and operational.
2. **Given** a bootstrapped Pi, **When** the gateway starts with the generated config, **Then** idle memory usage stays under 512MB.
3. **Given** a bootstrapped Pi, **When** the user runs the validation script, **Then** it confirms all agents can read/write to the coordination directory.

---

### User Story 5 — Add a Mac Companion Node (Priority: P3)

A developer wants to extend their Pi-hosted gateway with a Mac as a compute node. They run an optional setup script that configures the Mac as an OpenClaw node connected to the Pi gateway, enabling Mac-only capabilities while keeping the gateway on the Pi.

**Why this priority**: This is an optional extension — the base system must work on Pi alone first.

**Independent Test**: Can be tested by running the Mac node setup, then verifying the Pi gateway can dispatch work to the Mac node and receive results through the coordination filesystem.

**Acceptance Scenarios**:

1. **Given** a running Pi gateway, **When** the user runs the Mac node setup script, **Then** the Mac registers as a node with the Pi gateway.
2. **Given** a connected Mac node, **When** a task is dispatched to a Mac-capable agent, **Then** execution happens on the Mac and results appear in the coordination directory.
3. **Given** a Pi gateway without a Mac node, **When** a Mac-only agent is configured, **Then** the system gracefully reports that the node is unavailable rather than failing silently.

---

### User Story 6 — Run a Smoke Test (Priority: P2)

A developer wants to verify their scaffolded project is correctly configured before adding real agent logic. They run a validation script that checks directory structure, config validity, sandbox connectivity, and coordination file read/write from each agent's perspective.

**Why this priority**: Fast feedback on misconfiguration prevents wasted debugging time.

**Independent Test**: Can be tested by running the smoke test on a correctly scaffolded project (should pass) and on a deliberately broken project (should report specific failures).

**Acceptance Scenarios**:

1. **Given** a correctly scaffolded project, **When** the user runs the smoke test, **Then** all checks pass and a summary report is written to `coord/status/smoke-test.json`.
2. **Given** a project with a missing coordination directory, **When** the user runs the smoke test, **Then** the specific missing directory is reported as a failure.
3. **Given** a project with an invalid gateway config, **When** the user runs the smoke test, **Then** the config validation error is reported with the relevant section cited.

---

### Edge Cases

- What happens when the user scaffolds into a directory that already has an OpenClaw config? The tool should detect it and offer to merge or skip.
- What happens when Docker is not installed on the target machine? The bootstrap script should detect this and install it, or report a clear error if installation fails.
- What happens when the coordination directory mount path conflicts with an existing directory in a sandbox? The tool should detect and report the conflict.
- What happens when the Pi runs out of memory during multi-agent execution? The generated config should include memory limits per sandbox, and the system should fail individual agents gracefully rather than crashing the gateway.
- What happens when a worker agent's sandbox cannot write to the coordination directory? The smoke test should detect permission issues and report them with remediation steps.

## Out of Scope

- **Runtime management**: The tool does not start, stop, restart, or monitor the OpenClaw gateway or any agent. Users use the standard `openclaw` CLI for runtime operations.
- **LLM provider configuration**: The generated config includes placeholder sections for LLM providers, but the tool does not configure API keys or model selection.
- **Agent logic / prompts**: The tool generates role template files with instructions, but the actual agent behavior is the user's responsibility to customize.
- **Networking / firewall configuration**: Beyond the Docker sandbox network policy, the tool does not manage host networking, Tailscale, or SSH setup.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST scaffold a complete project directory layout from a single command, including coordination directories (`coord/inbox/`, `coord/outbox/`, `coord/artifacts/`, `coord/status/`, `coord/locks/`, `coord/signals/`), agent role templates, gateway config, and bootstrap scripts.
- **FR-002**: System MUST generate an OpenClaw gateway configuration where exactly one agent (communicator) is bound to user-facing channels, and all other agents are worker-only.
- **FR-003**: System MUST configure the communicator agent with `sandbox.mode: "off"` (unsandboxed on the host) and each worker agent with `sandbox.scope: "agent"` for Docker-based isolation.
- **FR-003a**: System MUST configure all worker sandboxes with `network: "bridge"` by default, granting network access to all workers.
- **FR-004**: System MUST configure a shared bind mount for the coordination directory (`/coord` inside sandboxes) using a narrow host path, and not expose broader host directories.
- **FR-005**: System MUST assign a unique `agentDir` to each agent — no two agents may share an auth store.
- **FR-006**: System MUST generate per-agent tool restriction policies that prevent worker agents from directly messaging users.
- **FR-007**: System MUST support customization of agent roles — users can specify which workers to include beyond the defaults.
- **FR-008**: System MUST generate a Pi bootstrap script that installs Node 22 and Docker on Raspberry Pi OS Lite (64-bit), creates the host-side coordination directory, and configures the gateway for conservative memory usage.
- **FR-009**: System MUST generate a smoke test script that validates directory structure, config syntax, sandbox connectivity, and coordination file read/write access from each agent's perspective.
- **FR-010**: System SHOULD generate an optional Mac node setup script that registers a Mac as a node with an existing Pi gateway.
- **FR-011**: System MUST generate structured file templates for agent coordination: `task.json`, `result.json`, `status.json`, and signal files like `ATTN.communicator`.
- **FR-012**: System MUST generate documentation (README, architecture brief) that explains the one-communicator pattern, file-first coordination model, and deployment instructions.
- **FR-013**: System MUST produce output that is compatible with ClawHub skill bundle format, including a valid `SKILL.md`.

### Key Entities

- **Project**: A scaffolded one-agent-one-task workspace with its directory tree, config, and scripts.
- **Agent Role**: A named agent with a defined responsibility, workspace, sandbox policy, and coordination paths (e.g., communicator, planner, coder).
- **Coordination Directory**: The shared filesystem contract (`coord/`) with subdirectories for inboxes, outboxes, artifacts, status, locks, and signals.
- **Gateway Config**: The OpenClaw configuration file defining all agents, their sandbox policies, bind mounts, and channel bindings.
- **Task File**: A structured JSON file (`task.json`) placed in an agent's inbox to assign work.
- **Result File**: A structured JSON file (`result.json`) placed in an agent's outbox to report completed work.
- **Signal File**: A narrow-purpose file (e.g., `ATTN.communicator`) used as the only permitted escape hatch for inter-agent attention requests.

## Clarifications

### Session 2026-03-08

- Q: Is the tool scaffold-only (generate files, user manages runtime) or does it also manage runtime (start/stop/monitor)? → A: Scaffold-only. The tool generates files, configs, and docs. The user runs the `openclaw` CLI for all runtime operations.
- Q: Should the communicator agent run inside a Docker sandbox or unsandboxed on the host? → A: Unsandboxed (`sandbox.mode: "off"`). Only worker agents are sandboxed.
- Q: What is the default network policy for worker sandboxes? → A: All workers get `network: "bridge"` (full network access) by default.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can scaffold a complete, valid project in under 30 seconds on a Raspberry Pi 5.
- **SC-002**: The generated gateway config passes OpenClaw config validation with zero errors on first run.
- **SC-003**: The smoke test suite validates all coordination paths and sandbox connectivity with a clear pass/fail report within 60 seconds.
- **SC-004**: The Pi bootstrap script completes a full installation (Node, Docker, gateway config) on a clean Pi OS Lite image in under 10 minutes with no manual intervention.
- **SC-005**: Idle memory usage of the gateway with default agent set (6 agents) stays under 512MB on the Raspberry Pi 5.
- **SC-006**: 100% of generated files are syntactically valid — JSON parses, shell scripts execute without syntax errors, markdown renders correctly.
- **SC-007**: A developer unfamiliar with OpenClaw can go from zero to a running multi-agent system by following only the generated README, with no external documentation required.
