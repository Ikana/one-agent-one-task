#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: smoke-test.sh [OPTIONS] [project-dir]

Options:
  --json         Emit machine-readable output
  --verbose      Show detailed check output
  --skip-docker  Skip Docker-based checks
  -h, --help     Show help
EOF
}

json5_to_json() {
  local file=$1
  sed '/^[[:space:]]*\/\//d' "$file"
}

record_check() {
  local name=$1
  local passed=$2
  local detail=$3

  CHECK_NAMES+=("$name")
  CHECK_PASSED+=("$passed")
  CHECK_DETAILS+=("$detail")

  if [[ $JSON_OUTPUT == false ]]; then
    if [[ $passed == true ]]; then
      printf '[OK] %s\n' "$name"
    else
      printf '[FAIL] %s\n' "$name"
    fi
    if [[ $VERBOSE == true && -n $detail ]]; then
      printf '  %s\n' "$detail"
    fi
  fi
}

build_checks_json() {
  local tmp_file
  local i
  tmp_file=$(mktemp)
  : >"$tmp_file"

  for i in "${!CHECK_NAMES[@]}"; do
    jq -cn \
      --arg name "${CHECK_NAMES[$i]}" \
      --argjson passed "$(json_bool "${CHECK_PASSED[$i]}")" \
      --arg detail "${CHECK_DETAILS[$i]}" \
      '{name: $name, passed: $passed, detail: $detail}' >>"$tmp_file"
  done

  jq -s '.' "$tmp_file"
  rm -f "$tmp_file"
}

write_status_file() {
  local project_dir=$1
  local payload=$2
  local status_file="$project_dir/coord/status/smoke-test.json"

  if [[ -d $project_dir/coord/status ]]; then
    printf '%s\n' "$payload" >"$status_file"
  fi
}

directory_structure_check() {
  local project_dir=$1
  local -a required=(
    "config"
    "agents"
    "coord/inbox"
    "coord/outbox"
    "coord/artifacts"
    "coord/status"
    "coord/locks"
    "coord/signals/communicator"
  )
  local -a missing=()
  local path

  for path in "${required[@]}"; do
    [[ -d $project_dir/$path ]] || missing+=("$path")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    record_check "directory_structure" true "Required project directories are present."
  else
    record_check "directory_structure" false "Missing directories: $(join_by ", " "${missing[@]}")."
  fi
}

config_syntax_check() {
  local project_dir=$1
  local config_file="$project_dir/config/openclaw.json5"
  local parsed_file
  local binding_agents

  if [[ ! -f $config_file ]]; then
    record_check "config_syntax" false "Missing config/openclaw.json5."
    return
  fi

  parsed_file=$(mktemp)
  json5_to_json "$config_file" >"$parsed_file"

  if ! jq empty "$parsed_file" >/dev/null 2>&1; then
    rm -f "$parsed_file"
    record_check "config_syntax" false "config/openclaw.json5 is not valid JSON after stripping JSON5 comments."
    return
  fi

  binding_agents=$(jq -rc '.bindings // [] | map(.agentId) | unique' "$parsed_file")
  if [[ $binding_agents != '["communicator"]' ]]; then
    rm -f "$parsed_file"
    record_check "config_syntax" false "Expected bindings[].agentId to reference only communicator."
    return
  fi

  rm -f "$parsed_file"
  record_check "config_syntax" true "Config parses and binds exactly one user-facing agent."
}

agent_dirs_unique_check() {
  local project_dir=$1
  local config_file="$project_dir/config/openclaw.json5"
  local parsed_file
  local total unique

  if [[ ! -f $config_file ]]; then
    record_check "agent_dirs_unique" false "Missing config/openclaw.json5."
    return
  fi

  parsed_file=$(mktemp)
  json5_to_json "$config_file" >"$parsed_file"

  if ! jq empty "$parsed_file" >/dev/null 2>&1; then
    rm -f "$parsed_file"
    record_check "agent_dirs_unique" false "Cannot evaluate agentDir uniqueness because the config is invalid."
    return
  fi

  total=$(jq '.agents.list | length' "$parsed_file")
  unique=$(jq '[.agents.list[].agentDir] | unique | length' "$parsed_file")

  rm -f "$parsed_file"

  if [[ $total -eq $unique ]]; then
    record_check "agent_dirs_unique" true "Each agent has a unique agentDir."
  else
    record_check "agent_dirs_unique" false "Duplicate agentDir values found in config/openclaw.json5."
  fi
}

coord_permissions_check() {
  local project_dir=$1
  local -a dirs=(
    "coord/inbox"
    "coord/outbox"
    "coord/artifacts"
    "coord/status"
    "coord/locks"
    "coord/signals/communicator"
  )
  local -a problems=()
  local dir
  local probe

  for dir in "${dirs[@]}"; do
    if [[ ! -d $project_dir/$dir ]]; then
      problems+=("$dir is missing")
      continue
    fi
    if [[ ! -r $project_dir/$dir ]]; then
      problems+=("$dir is not readable")
    fi
    if [[ ! -w $project_dir/$dir ]]; then
      problems+=("$dir is not writable")
      continue
    fi
    probe="$project_dir/$dir/.smoke-test-$$"
    if ! printf 'probe\n' >"$probe" 2>/dev/null; then
      problems+=("$dir rejected a write probe")
      continue
    fi
    rm -f "$probe"
  done

  if [[ ${#problems[@]} -eq 0 ]]; then
    record_check "coord_permissions" true "Read/write access succeeded across coordination directories."
  else
    record_check "coord_permissions" false "Permission issues: $(join_by "; " "${problems[@]}"). Remediation: ensure the current user can read and write the coord tree."
  fi
}

docker_available_check() {
  if [[ $SKIP_DOCKER == true ]]; then
    record_check "docker_available" true "Skipped because --skip-docker was set."
    return
  fi

  if ! command_exists docker; then
    record_check "docker_available" false "Docker is not installed or not on PATH."
    return
  fi

  if docker info >/dev/null 2>&1; then
    record_check "docker_available" true "Docker daemon is reachable."
  else
    record_check "docker_available" false "Docker daemon is not reachable. Remediation: start Docker or rerun with --skip-docker."
  fi
}

sandbox_bind_mount_check() {
  local project_dir=$1
  local config_file="$project_dir/config/openclaw.json5"
  local probe_host="$project_dir/coord/locks/smoke-bind-$$"
  local image="alpine:3.19"

  if [[ $SKIP_DOCKER == true ]]; then
    record_check "sandbox_bind_mount" true "Skipped because --skip-docker was set."
    return
  fi

  if ! command_exists docker || ! docker info >/dev/null 2>&1; then
    record_check "sandbox_bind_mount" false "Cannot verify bind mount because Docker is unavailable."
    return
  fi

  if [[ ! -f $config_file ]]; then
    record_check "sandbox_bind_mount" false "Missing config/openclaw.json5."
    return
  fi

  if ! json5_to_json "$config_file" | jq -e '[.agents.list[] | select(.id != "communicator") | .sandbox.docker.binds[]?] | any(endswith(":/coord:rw"))' >/dev/null; then
    record_check "sandbox_bind_mount" false "No worker sandbox bind mount targets /coord:rw."
    return
  fi

  rm -f "$probe_host"
  if ! docker run --rm -v "$project_dir/coord:/coord:rw" "$image" sh -lc "echo mounted >/coord/locks/$(basename "$probe_host") && cat /coord/locks/$(basename "$probe_host")" >/dev/null 2>&1; then
    record_check "sandbox_bind_mount" false "Docker could not read/write the coordination directory through /coord."
    rm -f "$probe_host"
    return
  fi

  rm -f "$probe_host"
  record_check "sandbox_bind_mount" true "Container read/write succeeded through /coord."
}

main() {
  require_command jq

  local project_dir="."
  local parsed_project_dir_set=false
  local summary
  local checks_json
  local payload
  local passed_count=0
  local total_count
  local i

  JSON_OUTPUT=false
  VERBOSE=false
  SKIP_DOCKER=false
  CHECK_NAMES=()
  CHECK_PASSED=()
  CHECK_DETAILS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        JSON_OUTPUT=true
        ;;
      --verbose)
        VERBOSE=true
        ;;
      --skip-docker)
        SKIP_DOCKER=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        die 1 "Unknown option: $1"
        ;;
      *)
        if [[ $parsed_project_dir_set == true ]]; then
          die 1 "Only one project directory is allowed"
        fi
        project_dir=$1
        parsed_project_dir_set=true
        ;;
    esac
    shift
  done

  project_dir=$(CDPATH= cd -- "$project_dir" 2>/dev/null && pwd) || die 1 "Project directory not found: $project_dir"

  directory_structure_check "$project_dir"
  config_syntax_check "$project_dir"
  agent_dirs_unique_check "$project_dir"
  coord_permissions_check "$project_dir"
  docker_available_check
  sandbox_bind_mount_check "$project_dir"

  total_count=${#CHECK_NAMES[@]}
  for i in "${!CHECK_PASSED[@]}"; do
    if [[ ${CHECK_PASSED[$i]} == true ]]; then
      passed_count=$((passed_count + 1))
    fi
  done

  summary="$passed_count/$total_count checks passed"
  checks_json=$(build_checks_json)
  payload=$(jq -n \
    --argjson passed "$(json_bool "$([[ $passed_count -eq $total_count ]] && printf 'true' || printf 'false')")" \
    --arg summary "$summary" \
    --argjson checks "$checks_json" \
    '{passed: $passed, checks: $checks, summary: $summary}')

  write_status_file "$project_dir" "$payload"

  if [[ $JSON_OUTPUT == true ]]; then
    printf '%s\n' "$payload"
  else
    printf '%s\n' "$summary"
  fi

  if [[ $passed_count -eq $total_count ]]; then
    exit 0
  fi

  exit 1
}

main "$@"
