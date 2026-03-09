# __PROJECT_NAME__

`__PROJECT_NAME__` is a scaffolded one-agent-one-task OpenClaw workspace.

## Overview

- Communicator: the only agent allowed to talk to the user
- Workers: __AGENTS__
- Coordination host path: `__COORD_HOST_PATH__`
- Sandbox mount path: `/coord`

## Coordination layout

```text
coord/
├── inbox/
├── outbox/
├── artifacts/
├── status/
├── locks/
└── signals/
    └── communicator/
```

## Quickstart

```bash
./scripts/bootstrap-pi.sh
./scripts/smoke-test.sh . --skip-docker
```

If Docker is available and the daemon is reachable, rerun the smoke test without `--skip-docker` to validate the `/coord` bind mount from a container.

## Files

- `config/openclaw.json5`: generated gateway configuration
- `agents/`: per-role `AGENT.md` instructions
- `templates/coordination/`: task, result, signal, and status contract examples
- `docs/architecture.md`: architecture rationale and tradeoffs
