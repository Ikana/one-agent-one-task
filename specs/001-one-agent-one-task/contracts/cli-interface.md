# CLI Interface Contract: One-Agent-One-Task

**Branch**: `001-one-agent-one-task` | **Date**: 2026-03-08

## Overview

The tool exposes its functionality through two interfaces:
1. **Shell scripts** — direct invocation for scaffolding, bootstrapping, and validation
2. **ClawHub skill** — invoked via `/one-agent-one-task` slash command inside an OpenClaw session

---

## Script Interface

### `scripts/scaffold.sh`

Generates the full project directory layout, config templates, and coordination directories.

**Usage**:
```
scaffold.sh [OPTIONS] <project-name>
```

**Arguments**:
| argument | required | description |
|----------|----------|-------------|
| `project-name` | yes | Name for the project (used in paths and config) |

**Options**:
| option | type | default | description |
|--------|------|---------|-------------|
| `--agents` | string | `"communicator,planner,researcher,coder,reviewer,runner"` | Comma-separated list of agent roles |
| `--coord-path` | string | `/var/lib/<project-name>/coord` | Host path for the coordination directory |
| `--output-dir` | string | `./<project-name>` | Where to create the project |
| `--force` | flag | false | Overwrite existing files without prompting |
| `--no-scripts` | flag | false | Skip generating bootstrap and smoke test scripts |
| `--json` | flag | false | Output results as JSON |

**Exit codes**:
| code | meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid arguments |
| 2 | Output directory exists and `--force` not set |
| 3 | File generation error |

**Output (default)**:
```
Created project: my-project
  Config: my-project/config/openclaw.json5
  Agents: communicator, planner, researcher, coder, reviewer, runner
  Coord:  /var/lib/my-project/coord
  Run:    my-project/scripts/bootstrap-pi.sh
```

**Output (--json)**:
```json
{
  "project": "my-project",
  "config": "my-project/config/openclaw.json5",
  "agents": ["communicator", "planner", "researcher", "coder", "reviewer", "runner"],
  "coord_host_path": "/var/lib/my-project/coord",
  "files_created": 42
}
```

---

### `scripts/bootstrap-pi.sh`

Installs prerequisites and configures the Pi for running the multi-agent gateway.

**Usage**:
```
bootstrap-pi.sh [OPTIONS]
```

**Options**:
| option | type | default | description |
|--------|------|---------|-------------|
| `--skip-docker` | flag | false | Don't install Docker (assume already installed) |
| `--skip-node` | flag | false | Don't install Node.js (assume already installed) |
| `--swap-size` | string | `"2G"` | Swap file size to create |
| `--coord-path` | string | `/var/lib/one-agent-one-task/coord` | Host coordination directory to create |
| `--dry-run` | flag | false | Print what would be done without executing |

**Requires**: Root or sudo access.

**Exit codes**:
| code | meaning |
|------|---------|
| 0 | Success |
| 1 | Not running on supported platform |
| 2 | Missing sudo/root access |
| 3 | Installation failure |

---

### `scripts/smoke-test.sh`

Validates the project setup: directory structure, config syntax, and sandbox connectivity.

**Usage**:
```
smoke-test.sh [OPTIONS] [project-dir]
```

**Arguments**:
| argument | required | description |
|----------|----------|-------------|
| `project-dir` | no (default: `.`) | Path to the project root |

**Options**:
| option | type | default | description |
|--------|------|---------|-------------|
| `--json` | flag | false | Output results as JSON |
| `--verbose` | flag | false | Show detailed output for each check |
| `--skip-docker` | flag | false | Skip Docker/sandbox connectivity checks |

**Exit codes**:
| code | meaning |
|------|---------|
| 0 | All checks passed |
| 1 | One or more checks failed |

**Output (--json)**:
```json
{
  "passed": true,
  "checks": [
    { "name": "directory_structure", "passed": true },
    { "name": "config_syntax", "passed": true },
    { "name": "agent_dirs_unique", "passed": true },
    { "name": "coord_permissions", "passed": true },
    { "name": "docker_available", "passed": true },
    { "name": "sandbox_bind_mount", "passed": true }
  ],
  "summary": "6/6 checks passed"
}
```

---

### `scripts/setup-mac-node.sh`

Configures a Mac as a companion node to the Pi gateway.

**Usage**:
```
setup-mac-node.sh [OPTIONS] <gateway-host>
```

**Arguments**:
| argument | required | description |
|----------|----------|-------------|
| `gateway-host` | yes | IP or hostname of the Pi gateway |

**Options**:
| option | type | default | description |
|--------|------|---------|-------------|
| `--gateway-port` | number | `18789` | Gateway port |
| `--dry-run` | flag | false | Print steps without executing |

**Exit codes**:
| code | meaning |
|------|---------|
| 0 | Success — node paired |
| 1 | Gateway unreachable |
| 2 | Pairing rejected |

---

## Coordination File Contracts

### task.json

```json
{
  "id": "task-001",
  "created_at": "2026-03-08T12:00:00Z",
  "assigned_to": "coder",
  "assigned_by": "communicator",
  "priority": "normal",
  "description": "Implement the login form component",
  "input_files": ["artifacts/login-spec.md"],
  "expected_output": "A working login form component with tests",
  "timeout_seconds": 300,
  "status": "pending"
}
```

### result.json

```json
{
  "task_id": "task-001",
  "agent_id": "coder",
  "completed_at": "2026-03-08T12:04:32Z",
  "status": "success",
  "output_files": ["artifacts/login-form.tsx", "artifacts/login-form.test.tsx"],
  "summary": "Implemented login form with email/password fields and validation",
  "error": null,
  "duration_seconds": 272
}
```

### signal.json

```json
{
  "id": "sig-001",
  "created_at": "2026-03-08T12:04:33Z",
  "from": "coder",
  "to": "communicator",
  "reason": "review_artifact",
  "path": "artifacts/login-form.tsx",
  "message": "Login form ready for review — includes email validation"
}
```

### status.json

```json
{
  "agent_id": "coder",
  "state": "idle",
  "current_task_id": null,
  "updated_at": "2026-03-08T12:04:33Z",
  "uptime_seconds": 1832,
  "tasks_completed": 3,
  "last_error": null
}
```
