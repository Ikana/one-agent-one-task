# one-agent-one-task

`one-agent-one-task` is a ClawHub skill bundle that scaffolds an OpenClaw workspace with one user-facing communicator and a set of file-coordinated worker agents.

## What it generates

- A JSON5 gateway config with one communicator and isolated worker agents
- Agent role files in `agents/<role>/AGENT.md`
- A coordination contract under `coord/` and `templates/coordination/`
- Support scripts for Pi bootstrap, smoke testing, and Mac node setup

## Install

```bash
# From ClawHub
clawhub install one-agent-one-task

# Or from a local checkout
clawhub install ./one-agent-one-task
```

## Usage

```bash
./scripts/scaffold.sh my-project

./scripts/scaffold.sh my-project \
  --agents "communicator,planner,coder,reviewer" \
  --coord-path "$PWD/my-project/coord"
```

The scaffold creates:

- `config/openclaw.json5`
- `agents/<role>/AGENT.md`
- `coord/` inbox, outbox, artifacts, status, locks, and signals directories
- `scripts/bootstrap-pi.sh`, `scripts/smoke-test.sh`, `scripts/setup-mac-node.sh`
- `docs/architecture.md`

## Validation

```bash
./scripts/smoke-test.sh my-project --skip-docker
```

If Docker is available and the daemon is reachable, omit `--skip-docker` to validate the bind mount from a container as well.

## Deployment

```bash
sudo my-project/scripts/bootstrap-pi.sh
my-project/scripts/setup-mac-node.sh <gateway-host> --dry-run
```

## Documentation

- [Quickstart](specs/001-one-agent-one-task/quickstart.md)
- [Architecture](docs/architecture.md)
- [CLI contract](specs/001-one-agent-one-task/contracts/cli-interface.md)
- [Design brief](docs/brief.md)

## License

MIT
