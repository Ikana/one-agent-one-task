# Quickstart: One-Agent-One-Task

**Branch**: `001-one-agent-one-task` | **Date**: 2026-03-08

## Prerequisites

- Raspberry Pi 5 (4GB+ RAM) with 64-bit Pi OS Lite, **or** any Linux machine with Docker
- SSH access to the Pi (if headless)
- An API key for your preferred LLM provider (Claude, GPT-4, etc.)

## Step 1: Install OpenClaw on the Pi

```bash
# SSH into your Pi
ssh pi@<your-pi-ip>

# Run the official OpenClaw installer
curl -fsSL https://openclaw.ai/install.sh | bash

# Follow the onboarding wizard to:
# - Configure your LLM provider
# - Set up at least one chat channel (WhatsApp, Telegram, etc.)

# Verify the gateway is running
openclaw doctor
```

## Step 2: Install the one-agent-one-task skill

```bash
# Install from ClawHub
clawhub install one-agent-one-task

# Or install from local directory
clawhub install ./one-agent-one-task
```

## Step 3: Scaffold your project

```bash
# Generate the full project layout
one-agent-one-task/scripts/scaffold.sh my-project

# Or customize the agent set
one-agent-one-task/scripts/scaffold.sh my-project \
  --agents "communicator,planner,coder,reviewer"
```

This creates:

```
my-project/
├── config/
│   └── openclaw.json5          # Gateway config with all agents
├── agents/
│   ├── communicator/
│   │   └── AGENT.md            # Role instructions
│   ├── planner/
│   │   └── AGENT.md
│   ├── researcher/
│   │   └── AGENT.md
│   ├── coder/
│   │   └── AGENT.md
│   ├── reviewer/
│   │   └── AGENT.md
│   └── runner/
│       └── AGENT.md
├── templates/
│   ├── task.json               # Task file template
│   ├── result.json             # Result file template
│   └── signal.json             # Signal file template
├── scripts/
│   ├── bootstrap-pi.sh         # Pi setup script
│   ├── smoke-test.sh           # Validation script
│   └── setup-mac-node.sh       # Optional Mac node setup
├── docs/
│   └── architecture.md         # Architecture brief
└── README.md
```

## Step 4: Bootstrap the Pi

```bash
# Run the Pi-specific bootstrap (installs Docker, creates coord dirs)
sudo my-project/scripts/bootstrap-pi.sh

# This will:
# - Install Docker if not present
# - Create /var/lib/my-project/coord with all subdirectories
# - Set correct permissions for the coordination directory
# - Add 2GB swap for stability
# - Enable Node compile cache
```

## Step 5: Apply the gateway config

```bash
# Back up existing config
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak

# Apply the generated multi-agent config
cp my-project/config/openclaw.json5 ~/.openclaw/openclaw.json

# The gateway will hot-reload the config automatically
# Verify with:
openclaw doctor
```

## Step 6: Run the smoke test

```bash
# Validate everything is wired up correctly
my-project/scripts/smoke-test.sh my-project

# Expected output:
# ✓ directory_structure
# ✓ config_syntax
# ✓ agent_dirs_unique
# ✓ coord_permissions
# ✓ docker_available
# ✓ sandbox_bind_mount
# 6/6 checks passed
```

## Step 7: Start using it

Send a message to your configured chat channel. The communicator agent will:

1. Receive your message
2. Break it into tasks
3. Dispatch tasks to workers via the coordination directory
4. Collect results
5. Respond to you with a summary

## Optional: Add a Mac companion node

```bash
# On your Mac, install the OpenClaw menubar app
# Then pair it with the Pi gateway:
my-project/scripts/setup-mac-node.sh <pi-ip-address>

# On the Pi, approve the pairing:
openclaw devices approve <requestId>
```

## What's next?

- **Customize agent roles**: Edit `agents/<role>/AGENT.md` to change each agent's instructions
- **Add new workers**: Re-run scaffold with `--agents` to add new roles
- **Monitor coordination**: Watch `coord/status/` for real-time agent state
- **Debug**: Check `coord/outbox/<agent>/` for result files and `coord/signals/` for attention requests
