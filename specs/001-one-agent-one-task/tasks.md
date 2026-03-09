# Tasks: One-Agent-One-Task

**Input**: Design documents from `/specs/001-one-agent-one-task/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/cli-interface.md, research.md, quickstart.md

**Tests**: Included — `tests/test-scaffold.sh` and `tests/test-smoke.sh` are part of the deliverables (smoke-test.sh is itself a user story, and scaffold tests validate the core MVP).

**Organization**: Tasks are grouped by user story. US1+US2+US3 are combined into a single phase because they are all P1 and tightly coupled through `scaffold.sh`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the skill bundle directory structure and shared utilities.

- [ ] T001 Create project directory structure per plan.md: `scripts/`, `templates/config/`, `templates/agents/`, `templates/coordination/`, `examples/minimal/`, `examples/full/`, `docs/`, `tests/`
- [ ] T002 Create `scripts/lib/common.sh` with shared utility functions: argument parsing helpers, color output, error/warn/info logging, JSON output helpers, platform detection

---

## Phase 2: Foundational (Templates)

**Purpose**: Write all template files that `scaffold.sh` will copy and process. These MUST be complete before the scaffold script can be implemented.

**⚠️ CRITICAL**: No user story work can begin until these templates exist.

### Config Template

- [ ] T003 [P] Write `templates/config/openclaw.json5` — gateway config template with: one communicator agent (`sandbox.mode: "off"`), worker agents (`sandbox.scope: "agent"`, `sandbox.mode: "non-main"`, `network: "bridge"`), per-agent unique `agentDir` paths, shared bind mount (`<COORD_HOST_PATH>:/coord:rw`), per-agent memory limits (384m), per-agent tool restrictions, LLM provider placeholder section. Use `<PLACEHOLDER>` markers for values that scaffold.sh will substitute.

### Agent Role Templates

- [ ] T004 [P] Write `templates/agents/communicator.md` — role template defining: sole user-facing agent, delegation logic via `sessions_spawn`, reading worker results from `/coord/outbox/`, reading signals from `/coord/signals/communicator/`, producing final user responses, writing task files to `/coord/inbox/<worker>/`
- [ ] T005 [P] Write `templates/agents/planner.md` — role template defining: converting user goals into task manifests, reading tasks from `/coord/inbox/planner/`, writing structured task breakdowns to `/coord/outbox/planner/`, explicit instruction "Never message the user directly"
- [ ] T006 [P] Write `templates/agents/researcher.md` — role template defining: gathering and synthesizing information, reading tasks from `/coord/inbox/researcher/`, writing research artifacts to `/coord/outbox/researcher/` and `/coord/artifacts/`, explicit instruction "Never message the user directly"
- [ ] T007 [P] Write `templates/agents/coder.md` — role template defining: writing implementation artifacts, reading tasks from `/coord/inbox/coder/`, writing code/patches to `/coord/outbox/coder/` and `/coord/artifacts/`, explicit instruction "Never message the user directly"
- [ ] T008 [P] Write `templates/agents/reviewer.md` — role template defining: reviewing artifacts and producing approval/rejection, reading tasks from `/coord/inbox/reviewer/`, writing review results to `/coord/outbox/reviewer/`, workspace access `"ro"`, explicit instruction "Never message the user directly"
- [ ] T009 [P] Write `templates/agents/runner.md` — role template defining: executing tests and controlled commands, reading tasks from `/coord/inbox/runner/`, writing logs and outcomes to `/coord/outbox/runner/`, explicit instruction "Never message the user directly"

### Coordination File Templates

- [ ] T010 [P] Write `templates/coordination/task.json` — template with all fields from data-model.md TaskFile entity: id, created_at, assigned_to, assigned_by, priority, description, input_files, expected_output, timeout_seconds, status. Include inline comments explaining each field.
- [ ] T011 [P] Write `templates/coordination/result.json` — template with all fields from data-model.md ResultFile entity: task_id, agent_id, completed_at, status, output_files, summary, error, duration_seconds. Include inline comments.
- [ ] T012 [P] Write `templates/coordination/signal.json` — template with all fields from data-model.md SignalFile entity: id, created_at, from, to, reason, path, message. Include inline comments.
- [ ] T013 [P] Write `templates/coordination/status.json` — template with all fields from data-model.md StatusFile entity: agent_id, state, current_task_id, updated_at, uptime_seconds, tasks_completed, last_error. Include inline comments.

**Checkpoint**: All templates ready — scaffold.sh can now be implemented.

---

## Phase 3: US1 + US2 + US3 — Core Scaffolding (Priority: P1) 🎯 MVP

**Goal**: `scaffold.sh` generates a complete, valid project from a single command with customizable agent roles and a correct OpenClaw gateway config.

**Independent Test**: Run `scaffold.sh my-project` in an empty directory → verify output tree has all expected dirs, valid JSON config, agent templates, coordination dirs, and scripts.

### Implementation

- [ ] T014 [US1] Write CLI argument parsing in `scripts/scaffold.sh` — parse: project-name (required), --agents (default: "communicator,planner,researcher,coder,reviewer,runner"), --coord-path (default: /var/lib/<name>/coord), --output-dir (default: ./<name>), --force, --no-scripts, --json. Source `scripts/lib/common.sh`. Exit code 1 on invalid args.
- [ ] T015 [US1] Implement non-empty directory detection in `scripts/scaffold.sh` — if output dir exists and is non-empty: warn and prompt for confirmation unless --force is set. Exit code 2 if user declines.
- [ ] T016 [US1] Implement project directory tree creation in `scripts/scaffold.sh` — create: `config/`, `agents/<agent>/` for each agent, `scripts/`, `docs/`, `coord/inbox/<worker>/`, `coord/outbox/<worker>/`, `coord/artifacts/`, `coord/status/`, `coord/locks/`, `coord/signals/communicator/` (per data-model.md layout). The communicator does NOT get inbox/outbox dirs.
- [ ] T017 [US2] Implement dynamic agent list processing in `scripts/scaffold.sh` — parse comma-separated --agents list, validate "communicator" is always included (add if missing), create per-agent directories (inbox, outbox for workers only), copy matching agent role template from `templates/agents/` (fall back to generic worker template if role name has no template).
- [ ] T018 [US3] Implement gateway config generation in `scripts/scaffold.sh` — read `templates/config/openclaw.json5`, substitute placeholders: project name, coord host path, generate per-agent entries in agents.list with unique agentDir paths, set communicator to `sandbox.mode: "off"`, set workers to `sandbox.scope: "agent"` + `sandbox.mode: "non-main"` + `network: "bridge"` + `memory: "384m"`. Write result to `<output>/config/openclaw.json5`.
- [ ] T019 [US1] Implement coordination file template copying in `scripts/scaffold.sh` — copy `templates/coordination/*.json` into `<output>/templates/coordination/` so the generated project has its own copies of the file contracts.
- [ ] T020 [US1] Implement script copying in `scripts/scaffold.sh` — unless --no-scripts: copy `scripts/bootstrap-pi.sh`, `scripts/smoke-test.sh`, `scripts/setup-mac-node.sh` into `<output>/scripts/`. Make all copied scripts executable.
- [ ] T021 [US1] Write `templates/readme.md` — generated project README template with: project name, architecture overview, agent list, coordination directory layout, quickstart steps (referencing bootstrap-pi.sh and smoke-test.sh), link to architecture.md.
- [ ] T022 [US1] Implement README generation and summary output in `scripts/scaffold.sh` — process templates/readme.md with project-specific values, write to `<output>/README.md`. Print human-readable summary (or --json output per cli-interface.md contract). Exit code 0 on success, 3 on file generation error.

**Checkpoint**: `scaffold.sh my-project` produces a complete project. US1+US2+US3 acceptance scenarios are testable.

---

## Phase 4: US6 — Smoke Test (Priority: P2)

**Goal**: `smoke-test.sh` validates a scaffolded project's directory structure, config syntax, and sandbox connectivity.

**Independent Test**: Run on a valid scaffolded project (expect all pass) and on a deliberately broken project (expect specific failures reported).

### Implementation

- [ ] T023 [US6] Write CLI argument parsing and check framework in `scripts/smoke-test.sh` — parse: project-dir (default: .), --json, --verbose, --skip-docker. Source `scripts/lib/common.sh`. Define check runner function that tracks pass/fail counts.
- [ ] T024 [US6] Implement directory structure validation in `scripts/smoke-test.sh` — verify all expected dirs exist: config/, agents/, coord/inbox/, coord/outbox/, coord/artifacts/, coord/status/, coord/locks/, coord/signals/communicator/. Report each missing dir by name.
- [ ] T025 [US6] Implement config syntax validation in `scripts/smoke-test.sh` — validate `config/openclaw.json5` parses correctly (use jq after stripping JSON5 comments, or `openclaw config show` if available). Verify all agentDir values are unique. Verify exactly one agent has user-facing channel bindings.
- [ ] T026 [US6] Implement coordination directory permission checks in `scripts/smoke-test.sh` — test read/write access to coord/ subdirectories from current user. Report specific permission failures with remediation steps.
- [ ] T027 [US6] Implement Docker availability and bind mount checks in `scripts/smoke-test.sh` — skip if --skip-docker. Check `docker info` succeeds. Optionally test coord bind mount by running a temp container with the mount and verifying file read/write.
- [ ] T028 [US6] Implement output formatting in `scripts/smoke-test.sh` — text mode: checkmark/cross per check with summary line. --json mode: output per cli-interface.md contract. --verbose: show detail for each check. Write results to `coord/status/smoke-test.json`. Exit 0 if all pass, 1 if any fail.

**Checkpoint**: `smoke-test.sh` validates scaffolded projects. US6 acceptance scenarios are testable.

---

## Phase 5: US4 — Pi Bootstrap (Priority: P2)

**Goal**: `bootstrap-pi.sh` installs Node 22, Docker, creates coordination dirs, and configures the Pi for the multi-agent gateway.

**Independent Test**: Run on a clean Raspberry Pi 5 with Pi OS Lite → verify Node 22 and Docker are installed, coordination directory exists with correct permissions, swap is configured.

### Implementation

- [ ] T029 [US4] Write platform detection and argument parsing in `scripts/bootstrap-pi.sh` — parse: --skip-docker, --skip-node, --swap-size (default: 2G), --coord-path (default: /var/lib/one-agent-one-task/coord), --dry-run. Detect arm64 Linux (fail with exit 1 if not). Check for root/sudo (fail with exit 2 if missing). Source `scripts/lib/common.sh`.
- [ ] T030 [US4] Implement Node 22 installation in `scripts/bootstrap-pi.sh` — skip if --skip-node or node v22 already installed. Install via NodeSource repository for arm64. Verify `node --version` reports v22.x. Set `NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache` in /etc/environment.
- [ ] T031 [US4] Implement Docker installation in `scripts/bootstrap-pi.sh` — skip if --skip-docker or docker already installed. Install via official Docker convenience script (`get.docker.com`). Add current user to docker group. Verify `docker info` succeeds. Exit 3 on installation failure.
- [ ] T032 [US4] Implement swap and coordination directory setup in `scripts/bootstrap-pi.sh` — create swap file at /swapfile (size from --swap-size), enable it, add to /etc/fstab. Create coordination host directory at --coord-path with all subdirectories, set permissions to allow gateway user read/write.
- [ ] T033 [US4] Implement --dry-run mode and post-install instructions in `scripts/bootstrap-pi.sh` — in dry-run: print each step that would be executed without running it. After install: print instructions for running the OpenClaw install script, applying the generated config, and running smoke-test.sh.

**Checkpoint**: `bootstrap-pi.sh` fully provisions a Pi. US4 acceptance scenarios are testable.

---

## Phase 6: US5 — Mac Companion Node (Priority: P3)

**Goal**: `setup-mac-node.sh` pairs a Mac with the Pi gateway as a companion node.

**Independent Test**: Run on a Mac with OpenClaw menubar app → verify it connects to a Pi gateway and the node appears in `openclaw nodes status`.

### Implementation

- [ ] T034 [US5] Write `scripts/setup-mac-node.sh` — parse: gateway-host (required), --gateway-port (default: 18789), --dry-run. Verify running on macOS. Check OpenClaw menubar app is installed. Test gateway reachability (curl gateway-host:gateway-port). Initiate node pairing. Print instructions for approving the pairing on the Pi (`openclaw devices approve <requestId>`). Verify node connectivity with `openclaw nodes status`. Exit 0 on success, 1 if gateway unreachable, 2 if pairing rejected.

**Checkpoint**: Mac node pairing works. US5 acceptance scenarios are testable.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, examples, skill bundle, and test scripts.

- [ ] T035 [P] Write `SKILL.md` with YAML frontmatter (`name: one-agent-one-task`, `description`, `user-invocable: true`, `metadata.openclaw.requires.bins: ["docker", "jq"]`) and markdown body with agent instructions for scaffolding, configuration, and deployment per plan.md Phase C
- [ ] T036 [P] Write `docs/architecture.md` — architecture decision record covering: why one gateway, why one communicator, why file-coordinated workers, security model (sandbox isolation, narrow mounts, unique agentDirs), tradeoffs (latency vs simplicity, sessions_spawn as control plane), and which decisions are officially supported vs practical convention vs custom layer (per plan.md key design decisions table)
- [ ] T037 [P] Write `examples/minimal/openclaw.json5` and `examples/minimal/README.md` — minimal working config with communicator + 2 workers (planner, coder), all settings explicit
- [ ] T038 [P] Write `examples/full/openclaw.json5` and `examples/full/README.md` — full config with communicator + 5 workers (planner, researcher, coder, reviewer, runner), all settings including memory limits, tool restrictions, and bind mounts
- [ ] T039 [P] Write `tests/test-scaffold.sh` — run scaffold.sh in temp dir and verify: output tree completeness, generated JSON is parseable with jq, custom --agents produces correct dirs, --force works on existing dir, --json output matches contract, communicator always included even if omitted from --agents
- [ ] T040 [P] Write `tests/test-smoke.sh` — run smoke-test.sh on a valid scaffolded project (expect exit 0 + all checks pass) and on a deliberately broken project with missing coord dir (expect exit 1 + specific failure reported)
- [ ] T041 Update root `README.md` with final installation instructions (clawhub install, manual install), usage examples, link to docs/architecture.md, and link to quickstart

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup (T001, T002) — BLOCKS all user stories
- **US1+US2+US3 (Phase 3)**: Depends on Foundational (all templates must exist)
- **US6 (Phase 4)**: Depends on Phase 3 (needs a scaffolded project to validate)
- **US4 (Phase 5)**: Independent of Phase 3/4 (Pi bootstrap doesn't need scaffold output) — can run in parallel with Phase 4
- **US5 (Phase 6)**: Independent of Phase 4/5 — can run in parallel
- **Polish (Phase 7)**: Can start as soon as Phase 3 completes; T039/T040 depend on Phase 3/4

### User Story Dependencies

- **US1+US2+US3 (P1)**: Can start after Foundational (Phase 2) — no dependencies on other stories
- **US6 (P2)**: Logically depends on US1 (needs scaffolded project) but script is independently implementable
- **US4 (P2)**: Fully independent — Pi bootstrap is standalone
- **US5 (P3)**: Fully independent — Mac node setup is standalone

### Within Phase 3 (Core Scaffolding)

- T014 (arg parsing) must come first
- T015 (dir detection) depends on T014
- T016 (agent processing) depends on T014
- T017 (config generation) depends on T014
- T018 (config gen) can parallel with T016
- T019 (template copying) depends on T016
- T020 (script copying) depends on T014
- T021 (README template) independent — [P]
- T022 (summary output) depends on all above

### Parallel Opportunities

- **Phase 2**: All template tasks (T003–T013) can run in parallel — different files, no dependencies
- **Phase 3**: T016, T017, T019, T020 can partially overlap after T014 completes
- **Phase 4 + Phase 5 + Phase 6**: Can all run in parallel after Phase 3
- **Phase 7**: All [P] tasks can run in parallel

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Launch ALL template tasks together (11 tasks, all different files):
T003: templates/config/openclaw.json5
T004: templates/agents/communicator.md
T005: templates/agents/planner.md
T006: templates/agents/researcher.md
T007: templates/agents/coder.md
T008: templates/agents/reviewer.md
T009: templates/agents/runner.md
T010: templates/coordination/task.json
T011: templates/coordination/result.json
T012: templates/coordination/signal.json
T013: templates/coordination/status.json
```

## Parallel Example: Phase 4 + 5 + 6

```bash
# After Phase 3 completes, launch all three in parallel:
Phase 4 (US6): smoke-test.sh
Phase 5 (US4): bootstrap-pi.sh
Phase 6 (US5): setup-mac-node.sh
```

---

## Implementation Strategy

### MVP First (Phase 1 + 2 + 3 Only)

1. Complete Phase 1: Setup (T001–T002)
2. Complete Phase 2: Foundational templates (T003–T013)
3. Complete Phase 3: Core scaffolding — scaffold.sh (T014–T022)
4. **STOP and VALIDATE**: Run `scaffold.sh my-project` → verify output tree, valid config, agent templates, coordination dirs
5. This delivers US1+US2+US3 — the core value proposition

### Incremental Delivery

1. Setup + Foundational + US1/US2/US3 → **MVP** (scaffold works)
2. Add US6 (smoke test) → **Validation** (projects can self-check)
3. Add US4 (Pi bootstrap) → **Deployable** (Pi can be provisioned)
4. Add US5 (Mac node) → **Extended** (multi-machine support)
5. Polish → **Publishable** (SKILL.md, docs, examples, tests)

### Parallel Team Strategy

With multiple developers after Phase 2:

- Developer A: Phase 3 (scaffold.sh — core, must be one person since it's one file)
- Developer B: Phase 5 (bootstrap-pi.sh — independent)
- Developer C: Phase 7 partial (SKILL.md, architecture.md — independent docs)
- After Phase 3: Developer A → Phase 4 (smoke-test.sh), Developer B → Phase 6 (setup-mac-node.sh)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US1+US2+US3 are combined because they share `scaffold.sh` — they cannot be independently implemented
- Each phase after Phase 3 is independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate the current increment
- All paths are relative to the skill bundle root (`one-agent-one-task/`)
