# Data Model: One-Agent-One-Task

**Branch**: `001-one-agent-one-task` | **Date**: 2026-03-08

## Entities

### Project

A scaffolded one-agent-one-task workspace. Not persisted as data — it's the directory tree itself.

**Attributes**:
- `name` (string): Project name, used in directory paths and config identifiers
- `coord_host_path` (string): Host-side coordination directory path (default: `/var/lib/<name>/coord`)
- `coord_mount_path` (string): Mount path inside sandboxes (always `/coord`)
- `agents` (array of AgentRole): The set of configured agents

**Relationships**: Contains many AgentRoles. Produces one GatewayConfig.

---

### AgentRole

A named agent with a defined responsibility, sandbox policy, and coordination paths.

**Attributes**:
- `id` (string): Unique agent identifier (e.g., `communicator`, `planner`, `coder`)
- `type` (enum): `communicator` | `worker`
- `description` (string): Human-readable purpose statement
- `workspace` (string): Path to the agent's workspace directory
- `agentDir` (string): Path to the agent's per-agent state directory (must be unique per agent)
- `sandbox_mode` (enum): `off` | `non-main` | `all`
- `sandbox_scope` (enum): `session` | `agent` | `shared`
- `workspace_access` (enum): `rw` | `ro` | `none`
- `memory_limit` (string): Docker memory limit (e.g., `"384m"`)
- `cpu_limit` (number): Docker CPU limit (e.g., `1`)
- `network` (enum): `none` | `bridge` — whether the sandbox has network access
- `tools_allowed` (array of string): Whitelist of tools this agent may use
- `tools_denied` (array of string): Blacklist of tools this agent may not use

**Relationships**: Belongs to one Project. Has one inbox, one outbox, zero or more signal targets.

**Validation rules**:
- `id` must be unique across all agents in the project
- `agentDir` must be unique across all agents (never shared)
- Exactly one agent must have `type: "communicator"`
- Workers must not have user-facing channel bindings in their tool set

---

### TaskFile

A structured JSON file placed in an agent's inbox to assign work.

**Attributes**:
- `id` (string): Unique task identifier (UUID or sequential)
- `created_at` (ISO 8601 string): When the task was created
- `assigned_to` (string): Agent ID of the worker
- `assigned_by` (string): Agent ID of the assigner (usually `communicator`)
- `priority` (enum): `low` | `normal` | `high` | `critical`
- `description` (string): Human-readable task description
- `input_files` (array of string): Paths to input artifacts in `coord/artifacts/`
- `expected_output` (string): Description of expected deliverable
- `timeout_seconds` (number): Maximum time allowed for the task
- `status` (enum): `pending` | `in_progress` | `completed` | `failed` | `cancelled`

**File location**: `coord/inbox/<agent>/<task-id>.task.json`

**Validation rules**:
- `assigned_to` must match a valid agent ID
- `status` transitions: `pending` → `in_progress` → `completed` | `failed`
- `input_files` paths must be relative to `coord/`

---

### ResultFile

A structured JSON file placed in an agent's outbox to report completed work.

**Attributes**:
- `task_id` (string): References the originating TaskFile
- `agent_id` (string): The worker that produced this result
- `completed_at` (ISO 8601 string): When the work finished
- `status` (enum): `success` | `failure` | `partial`
- `output_files` (array of string): Paths to output artifacts in `coord/artifacts/`
- `summary` (string): Brief human-readable summary of what was done
- `error` (string | null): Error message if status is `failure`
- `duration_seconds` (number): How long the task took

**File location**: `coord/outbox/<agent>/<task-id>.result.json`

**Validation rules**:
- `task_id` must reference an existing task
- `output_files` paths must be relative to `coord/`
- `error` must be non-null when `status` is `failure`

---

### StatusFile

A structured JSON file reflecting an agent's current state.

**Attributes**:
- `agent_id` (string): Which agent this status belongs to
- `state` (enum): `idle` | `busy` | `error` | `offline`
- `current_task_id` (string | null): The task currently being worked on
- `updated_at` (ISO 8601 string): Last status update time
- `uptime_seconds` (number): How long the agent has been running
- `tasks_completed` (number): Lifetime count of completed tasks
- `last_error` (string | null): Most recent error message

**File location**: `coord/status/<agent>.status.json`

---

### SignalFile

A narrow-purpose file used as the escape hatch for inter-agent attention requests.

**Attributes**:
- `id` (string): Unique signal identifier
- `created_at` (ISO 8601 string): When the signal was created
- `from` (string): Agent ID of the sender
- `to` (string): Agent ID of the recipient (usually `communicator`)
- `reason` (enum): `review_artifact` | `task_blocked` | `error_escalation` | `approval_needed`
- `path` (string): Path to the relevant artifact in `coord/`
- `message` (string): Brief human-readable context

**File location**: `coord/signals/<target-agent>/<signal-id>.signal.json`

**Validation rules**:
- Workers may only signal the communicator
- `path` must reference a real file in `coord/`
- Signals are append-only — never modified, only created

---

## State Transitions

### Task Lifecycle

```
[created] → pending → in_progress → completed
                    ↘              ↗
                      → failed
                    ↘
                      → cancelled
```

- `pending`: Task file written to inbox, worker not yet picked it up
- `in_progress`: Worker has claimed the task and started work
- `completed`: Worker finished successfully, result file written
- `failed`: Worker encountered an error, result file written with error details
- `cancelled`: Communicator withdrew the task before completion

### Agent State Machine

```
[start] → idle ↔ busy → idle
              ↘       ↗
                error → idle (after recovery)
              ↘
                offline (sandbox stopped)
```

## Directory Layout (Coordination)

```
coord/
├── inbox/
│   ├── planner/          # Tasks assigned to planner
│   ├── researcher/       # Tasks assigned to researcher
│   ├── coder/            # Tasks assigned to coder
│   ├── reviewer/         # Tasks assigned to reviewer
│   └── runner/           # Tasks assigned to runner
├── outbox/
│   ├── planner/          # Results from planner
│   ├── researcher/       # Results from researcher
│   ├── coder/            # Results from coder
│   ├── reviewer/         # Results from reviewer
│   └── runner/           # Results from runner
├── artifacts/            # Shared work products (code, docs, patches)
├── status/               # Per-agent status files
├── locks/                # File-based locks for coordination
└── signals/
    └── communicator/     # Attention signals for the communicator
```
