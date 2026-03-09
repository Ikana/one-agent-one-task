#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: bootstrap-pi.sh [OPTIONS]

Options:
  --skip-docker        Skip Docker installation
  --skip-node          Skip Node.js installation
  --swap-size <size>   Swap file size (default: 2G)
  --coord-path <path>  Coordination host path (default: /var/lib/one-agent-one-task/coord)
  --dry-run            Print steps without executing them
  -h, --help           Show help
EOF
}

run_root() {
  if [[ $DRY_RUN == true ]]; then
    printf '[dry-run] %s\n' "$*" >&2
    return
  fi

  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

run_root_shell() {
  if [[ $DRY_RUN == true ]]; then
    printf '[dry-run] %s\n' "$*" >&2
    return
  fi

  if [[ $EUID -eq 0 ]]; then
    bash -lc "$*"
  else
    sudo bash -lc "$*"
  fi
}

ensure_environment_var() {
  local key=$1
  local value=$2
  local file=/etc/environment
  local escaped

  escaped=$(printf '%s' "$value" | sed 's/[\/&]/\\&/g')

  if [[ $DRY_RUN == true ]]; then
    printf '[dry-run] ensure %s=%s in %s\n' "$key" "$value" "$file" >&2
    return
  fi

  if run_root_shell "grep -q '^${key}=' '$file'"; then
    run_root_shell "sed -i.bak 's/^${key}=.*/${key}=${escaped}/' '$file'"
  else
    run_root_shell "printf '%s=%s\n' '$key' '$value' >> '$file'"
  fi
}

install_node() {
  if [[ $SKIP_NODE == true ]]; then
    info "Skipping Node.js installation"
    return
  fi

  if command_exists node && node --version | grep -q '^v22\.'; then
    info "Node.js 22 already installed"
  else
    info "Installing Node.js 22"
    run_root_shell "curl -fsSL https://deb.nodesource.com/setup_22.x | bash -"
    run_root apt-get install -y nodejs
    if ! node --version | grep -q '^v22\.'; then
      die 3 "Node.js 22 installation verification failed"
    fi
  fi

  ensure_environment_var "NODE_COMPILE_CACHE" "/var/tmp/openclaw-compile-cache"
}

install_docker() {
  if [[ $SKIP_DOCKER == true ]]; then
    info "Skipping Docker installation"
    return
  fi

  if command_exists docker && docker info >/dev/null 2>&1; then
    info "Docker already installed and reachable"
    return
  fi

  info "Installing Docker"
  run_root_shell "curl -fsSL https://get.docker.com | sh"

  if [[ -n ${SUDO_USER:-} ]]; then
    run_root usermod -aG docker "$SUDO_USER"
  elif [[ $EUID -eq 0 && -n ${USER:-} ]]; then
    run_root usermod -aG docker "$USER"
  fi

  if [[ $DRY_RUN == false ]] && ! docker info >/dev/null 2>&1; then
    die 3 "Docker installation verification failed"
  fi
}

configure_swap() {
  local fstab_entry="/swapfile none swap sw 0 0"

  info "Configuring swap"
  if [[ $DRY_RUN == false && -f /swapfile ]]; then
    warn "/swapfile already exists; leaving it in place"
  else
    run_root fallocate -l "$SWAP_SIZE" /swapfile
    run_root chmod 600 /swapfile
    run_root mkswap /swapfile
  fi

  if [[ $DRY_RUN == false ]]; then
    if ! grep -q '^/swapfile ' /etc/fstab; then
      run_root_shell "printf '%s\n' '$fstab_entry' >> /etc/fstab"
    fi
    if ! swapon --show | grep -q '^/swapfile'; then
      run_root swapon /swapfile
    fi
  else
    printf '[dry-run] ensure %s is present in /etc/fstab\n' "$fstab_entry" >&2
    printf '[dry-run] swapon /swapfile\n' >&2
  fi
}

create_coord_dirs() {
  local owner=${SUDO_USER:-${USER:-root}}

  info "Creating coordination directories at $COORD_PATH"
  run_root mkdir -p \
    "$COORD_PATH/inbox/planner" \
    "$COORD_PATH/inbox/researcher" \
    "$COORD_PATH/inbox/coder" \
    "$COORD_PATH/inbox/reviewer" \
    "$COORD_PATH/inbox/runner" \
    "$COORD_PATH/outbox/planner" \
    "$COORD_PATH/outbox/researcher" \
    "$COORD_PATH/outbox/coder" \
    "$COORD_PATH/outbox/reviewer" \
    "$COORD_PATH/outbox/runner" \
    "$COORD_PATH/artifacts" \
    "$COORD_PATH/status" \
    "$COORD_PATH/locks" \
    "$COORD_PATH/signals/communicator"

  run_root chown -R "$owner":"$owner" "$COORD_PATH"
  run_root chmod -R ug+rwX,o-rwx "$COORD_PATH"
}

post_install_instructions() {
  cat <<EOF
Post-install steps:
  1. Install OpenClaw if needed:
     curl -fsSL https://openclaw.ai/install.sh | bash
  2. Generate a project scaffold and copy its config into ~/.openclaw/openclaw.json
  3. Run the scaffolded smoke test:
     ./scripts/smoke-test.sh <project-dir>
EOF
}

main() {
  DRY_RUN=false
  SKIP_DOCKER=false
  SKIP_NODE=false
  SWAP_SIZE="2G"
  COORD_PATH="/var/lib/one-agent-one-task/coord"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-docker)
        SKIP_DOCKER=true
        ;;
      --skip-node)
        SKIP_NODE=true
        ;;
      --swap-size)
        shift
        [[ $# -gt 0 ]] || die 1 "Missing value for --swap-size"
        SWAP_SIZE=$1
        ;;
      --coord-path)
        shift
        [[ $# -gt 0 ]] || die 1 "Missing value for --coord-path"
        COORD_PATH=$1
        ;;
      --dry-run)
        DRY_RUN=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die 1 "Unknown option: $1"
        ;;
    esac
    shift
  done

  if ! is_linux || ! is_arm64; then
    die 1 "bootstrap-pi.sh supports arm64 Linux only (detected $(platform_name))"
  fi

  if [[ $EUID -ne 0 ]] && ! command_exists sudo; then
    die 2 "Run as root or install sudo"
  fi

  install_node
  install_docker
  configure_swap
  create_coord_dirs
  post_install_instructions
}

main "$@"
