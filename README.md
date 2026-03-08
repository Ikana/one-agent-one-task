# one-agent-one-task

A disciplined multi-agent architecture where exactly one communicator agent talks to the user, all worker agents run in Docker-backed sandboxes, and agents communicate through files — not chat.

## Principles

1. **One communicator only** — a single agent owns all user-facing communication
2. **File-first coordination** — workers exchange structured files through a shared filesystem contract, not conversational APIs
3. **No agent chat bus** — inter-agent chat is not the data plane
4. **Strong isolation** — each worker gets its own sandbox, workspace, and limited responsibility
5. **Boring infrastructure** — prefer well-maintained, officially supported paths

## Architecture

- One OpenClaw Gateway
- One communicator agent (user-facing)
- Multiple sandboxed worker agents (planner, researcher, coder, reviewer, runner)
- Shared coordination directory mounted into sandboxes at `/coord`

## Deployment Targets

- **Primary:** Raspberry Pi 5 Model B (4GB RAM, 4 cores, 64-bit Pi OS Lite)
- **Optional:** Mac companion node connected to the Pi gateway

## Status

Early design phase. See [the brief](docs/brief.md) for the full design document.

## License

MIT
