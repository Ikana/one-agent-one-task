#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: setup-mac-node.sh [OPTIONS] <gateway-host>

Options:
  --gateway-port <port>  Gateway port (default: 18789)
  --dry-run              Print steps without executing them
  -h, --help             Show help
EOF
}

find_openclaw_app() {
  local candidate
  for candidate in "/Applications/OpenClaw.app" "$HOME/Applications/OpenClaw.app"; do
    if [[ -d $candidate ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

main() {
  local gateway_host=""
  local gateway_port="18789"
  local dry_run=false
  local app_path=""
  local display_name
  local status_output

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gateway-port)
        shift
        [[ $# -gt 0 ]] || die 1 "Missing value for --gateway-port"
        gateway_port=$1
        ;;
      --dry-run)
        dry_run=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        die 1 "Unknown option: $1"
        ;;
      *)
        if [[ -n $gateway_host ]]; then
          die 1 "Only one gateway host is allowed"
        fi
        gateway_host=$1
        ;;
    esac
    shift
  done

  [[ -n $gateway_host ]] || die 1 "Gateway host is required"
  is_macos || die 1 "setup-mac-node.sh supports macOS only (detected $(platform_name))"

  if app_path=$(find_openclaw_app); then
    info "Found OpenClaw app at $app_path"
  elif command_exists openclaw; then
    info "OpenClaw CLI is available"
  else
    die 2 "OpenClaw menubar app or CLI is required on this Mac"
  fi

  if [[ $dry_run == false ]]; then
    if ! curl -sS --connect-timeout 5 "http://$gateway_host:$gateway_port" -o /dev/null; then
      die 1 "Gateway is unreachable at http://$gateway_host:$gateway_port"
    fi
  else
    printf '[dry-run] curl -sS --connect-timeout 5 http://%s:%s\n' "$gateway_host" "$gateway_port" >&2
  fi

  display_name=$(scutil --get ComputerName 2>/dev/null || hostname)

  if command_exists openclaw; then
    if [[ $dry_run == true ]]; then
      printf '[dry-run] openclaw node install --host %s --port %s --display-name %q\n' "$gateway_host" "$gateway_port" "$display_name" >&2
      printf '[dry-run] openclaw node restart\n' >&2
    else
      openclaw node install --host "$gateway_host" --port "$gateway_port" --display-name "$display_name"
      openclaw node restart
    fi
  elif [[ -n $app_path ]]; then
    if [[ $dry_run == true ]]; then
      printf '[dry-run] open -a %q\n' "$app_path" >&2
    else
      open -a "$app_path"
    fi
  fi

  cat <<EOF
Approve the pairing on the gateway:
  openclaw devices approve <requestId>
EOF

  if ! command_exists openclaw || [[ $dry_run == true ]]; then
    exit 0
  fi

  if status_output=$(openclaw nodes status 2>/dev/null); then
    if printf '%s\n' "$status_output" | grep -qiE '(connected|online|healthy)'; then
      printf '%s\n' "$status_output"
      exit 0
    fi
  fi

  die 2 "Pairing has not been confirmed yet. Approve the request on the gateway, then rerun openclaw nodes status."
}

main "$@"
