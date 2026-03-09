#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

source "$SCRIPT_DIR/lib/common.sh"

DEFAULT_AGENTS="communicator,planner,researcher,coder,reviewer,runner"
AGENTS=()

usage() {
  cat <<'EOF'
Usage: scaffold.sh [OPTIONS] <project-name>

Options:
  --agents <csv>       Comma-separated list of agent roles
  --coord-path <path>  Host coordination path (default: /var/lib/<project>/coord)
  --output-dir <path>  Output directory (default: ./<project>)
  --force              Overwrite into a non-empty output directory without prompting
  --no-scripts         Skip copying helper scripts into the generated project
  --json               Emit machine-readable summary
  -h, --help           Show help
EOF
}

display_path() {
  local path=$1
  path=${path#./}
  printf '%s' "$path"
}

agent_tools_json() {
  local agent=$1
  case "$agent" in
    communicator) printf '%s' '["sessions_spawn","fs.read","fs.write","channels.send"]' ;;
    planner) printf '%s' '["fs.read","fs.write","sessions_spawn"]' ;;
    researcher) printf '%s' '["fs.read","fs.write","web.search"]' ;;
    coder) printf '%s' '["fs.read","fs.write","run.test"]' ;;
    reviewer) printf '%s' '["fs.read","review.code"]' ;;
    runner) printf '%s' '["fs.read","fs.write","run.test"]' ;;
    *) printf '%s' '["fs.read","fs.write"]' ;;
  esac
}

workspace_access_for() {
  if [[ $1 == "reviewer" ]]; then
    printf 'ro'
  else
    printf 'rw'
  fi
}

build_agent_object() {
  local agent=$1
  local coord_path=$2
  local role_file="/workspace/agents/$agent/AGENT.md"
  local agent_dir="/workspace/state/$agent"

  if [[ $agent == "communicator" ]]; then
    jq -cn \
      --arg id "$agent" \
      --arg roleFile "$role_file" \
      --arg agentDir "$agent_dir" \
      '{
        id: $id,
        workspace: "/workspace",
        agentDir: $agentDir,
        roleFile: $roleFile,
        sandbox: {
          mode: "off",
          workspaceAccess: "rw"
        },
        tools: {
          allow: ["sessions_spawn", "fs.read", "fs.write", "channels.send"],
          deny: []
        }
      }'
    return
  fi

  jq -cn \
    --arg id "$agent" \
    --arg roleFile "$role_file" \
    --arg agentDir "$agent_dir" \
    --arg workspaceAccess "$(workspace_access_for "$agent")" \
    --arg coordBind "${coord_path}:/coord:rw" \
    --argjson allow "$(agent_tools_json "$agent")" \
    '{
      id: $id,
      workspace: "/workspace",
      agentDir: $agentDir,
      roleFile: $roleFile,
      sandbox: {
        mode: "non-main",
        scope: "agent",
        workspaceAccess: $workspaceAccess,
        docker: {
          memory: "384m",
          cpus: 1,
          network: "bridge",
          binds: [$coordBind]
        }
      },
      tools: {
        allow: $allow,
        deny: ["channels.send", "message_user"]
      }
    }'
}

normalize_agents() {
  local input=$1
  local raw agent
  local -a raw_agents=()
  local -a ordered=()

  IFS=',' read -r -a raw_agents <<<"$input"
  for raw in "${raw_agents[@]}"; do
    agent=$(trim "$raw")
    [[ -n $agent ]] || continue
    [[ $agent =~ ^[a-z][a-z0-9-]*$ ]] || die 1 "Invalid agent id: $agent"
    if [[ $agent == "communicator" ]]; then
      continue
    fi
    if [[ ${#ordered[@]} -eq 0 ]] || ! array_contains "$agent" "${ordered[@]}"; then
      ordered+=("$agent")
    fi
  done

  AGENTS=("communicator")
  if [[ ${#ordered[@]} -gt 0 ]]; then
    AGENTS+=("${ordered[@]}")
  fi
  [[ ${#AGENTS[@]} -gt 0 ]] || die 1 "At least one agent is required"
}

copy_agent_template() {
  local agent=$1
  local destination=$2
  local template="$ROOT_DIR/templates/agents/$agent.md"

  if [[ ! -f $template ]]; then
    template="$ROOT_DIR/templates/agents/generic-worker.md"
  fi

  sed "s/__AGENT_ID__/$agent/g" "$template" >"$destination"
}

generate_config() {
  local project_name=$1
  local coord_path=$2
  local output_file=$3
  local header
  local agent_json_lines=()
  local agent
  local agents_json

  [[ -f $ROOT_DIR/templates/config/openclaw.json5 ]] || die 3 "Missing config template"
  header=$(sed -n '1p' "$ROOT_DIR/templates/config/openclaw.json5")

  for agent in "${AGENTS[@]}"; do
    agent_json_lines+=("$(build_agent_object "$agent" "$coord_path")")
  done

  agents_json=$(printf '%s\n' "${agent_json_lines[@]}" | jq -s '.')

  {
    printf '%s\n' "$header"
    jq -n \
      --arg projectName "$project_name" \
      --arg coordPath "$coord_path" \
      --argjson agents "$agents_json" \
      '{
        gateway: {
          name: $projectName,
          logLevel: "info"
        },
        bindings: [
          {
            channel: "telegram",
            agentId: "communicator"
          }
        ],
        coordination: {
          hostPath: $coordPath,
          mountPath: "/coord"
        },
        agents: {
          defaults: {
            workspace: "/workspace"
          },
          list: $agents
        },
        providers: {
          default: {
            provider: "REPLACE_ME",
            model: "REPLACE_ME"
          }
        }
      }'
  } >"$output_file"
}

generate_readme() {
  local project_name=$1
  local coord_path=$2
  local output_file=$3
  local agent_summary
  local line

  agent_summary=$(join_by ", " "${AGENTS[@]}")

  while IFS= read -r line; do
    line=${line//__PROJECT_NAME__/$project_name}
    line=${line//__AGENTS__/$agent_summary}
    line=${line//__COORD_HOST_PATH__/$coord_path}
    printf '%s\n' "$line"
  done <"$ROOT_DIR/templates/readme.md" >"$output_file"
}

copy_scripts() {
  local destination_root=$1
  local script_name

  mkdir -p "$destination_root/scripts/lib"
  cp "$ROOT_DIR/scripts/lib/common.sh" "$destination_root/scripts/lib/common.sh"
  for script_name in bootstrap-pi.sh smoke-test.sh setup-mac-node.sh; do
    cp "$ROOT_DIR/scripts/$script_name" "$destination_root/scripts/$script_name"
    chmod +x "$destination_root/scripts/$script_name"
  done
}

main() {
  require_command jq

  local project_name=""
  local agents_csv=$DEFAULT_AGENTS
  local coord_path=""
  local output_dir=""
  local output_dir_abs=""
  local output_dir_display=""
  local json_output=false
  local force=false
  local no_scripts=false
  local config_display=""
  local bootstrap_display=""
  local files_created=0
  local argument

  while [[ $# -gt 0 ]]; do
    argument=$1
    case "$argument" in
      --agents)
        shift
        [[ $# -gt 0 ]] || die 1 "Missing value for --agents"
        agents_csv=$1
        ;;
      --coord-path)
        shift
        [[ $# -gt 0 ]] || die 1 "Missing value for --coord-path"
        coord_path=$1
        ;;
      --output-dir)
        shift
        [[ $# -gt 0 ]] || die 1 "Missing value for --output-dir"
        output_dir=$1
        ;;
      --force)
        force=true
        ;;
      --no-scripts)
        no_scripts=true
        ;;
      --json)
        json_output=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        die 1 "Unknown option: $argument"
        ;;
      *)
        if [[ -n $project_name ]]; then
          die 1 "Only one project name is allowed"
        fi
        project_name=$argument
        ;;
    esac
    shift
  done

  [[ -n $project_name ]] || die 1 "Project name is required"
  normalize_agents "$agents_csv"

  if [[ -z $coord_path ]]; then
    coord_path="/var/lib/$project_name/coord"
  fi

  if [[ -z $output_dir ]]; then
    output_dir="./$project_name"
  fi

  mkdir -p "$(dirname "$output_dir")"
  output_dir_abs="$(CDPATH= cd -- "$(dirname "$output_dir")" && pwd)/$(basename "$output_dir")"
  output_dir_display=$(display_path "$output_dir")
  config_display="$output_dir_display/config/openclaw.json5"
  bootstrap_display="$output_dir_display/scripts/bootstrap-pi.sh"

  if [[ -e $output_dir_abs && ! -d $output_dir_abs ]]; then
    die 3 "Output path exists and is not a directory: $output_dir_display"
  fi

  if is_directory_nonempty "$output_dir_abs"; then
    if [[ $force == true ]]; then
      warn "Output directory is not empty, continuing because --force was set: $output_dir_display"
    else
      warn "Output directory already exists and is not empty: $output_dir_display"
      if ! confirm "Continue and add generated files to $output_dir_display?"; then
        exit 2
      fi
    fi
  fi

  trap 'die 3 "File generation failed"' ERR

  mkdir -p \
    "$output_dir_abs/config" \
    "$output_dir_abs/scripts" \
    "$output_dir_abs/docs" \
    "$output_dir_abs/templates/coordination" \
    "$output_dir_abs/agents" \
    "$output_dir_abs/state" \
    "$output_dir_abs/coord/inbox" \
    "$output_dir_abs/coord/outbox" \
    "$output_dir_abs/coord/artifacts" \
    "$output_dir_abs/coord/status" \
    "$output_dir_abs/coord/locks" \
    "$output_dir_abs/coord/signals/communicator"

  local agent
  for agent in "${AGENTS[@]}"; do
    mkdir -p "$output_dir_abs/agents/$agent" "$output_dir_abs/state/$agent"
    copy_agent_template "$agent" "$output_dir_abs/agents/$agent/AGENT.md"
    if [[ $agent != "communicator" ]]; then
      mkdir -p "$output_dir_abs/coord/inbox/$agent" "$output_dir_abs/coord/outbox/$agent"
    fi
  done

  cp "$ROOT_DIR/templates/coordination/"*.json "$output_dir_abs/templates/coordination/"
  cp "$ROOT_DIR/docs/architecture.md" "$output_dir_abs/docs/architecture.md"

  if [[ $no_scripts == false ]]; then
    copy_scripts "$output_dir_abs"
  fi

  generate_config "$project_name" "$coord_path" "$output_dir_abs/config/openclaw.json5"
  generate_readme "$project_name" "$coord_path" "$output_dir_abs/README.md"

  files_created=$(find "$output_dir_abs" -type f | wc -l | tr -d ' ')

  if [[ $json_output == true ]]; then
    jq -n \
      --arg project "$project_name" \
      --arg config "$config_display" \
      --arg coord_host_path "$coord_path" \
      --argjson agents "$(printf '%s\n' "${AGENTS[@]}" | jq -R . | jq -s '.')" \
      --argjson files_created "$files_created" \
      '{
        project: $project,
        config: $config,
        agents: $agents,
        coord_host_path: $coord_host_path,
        files_created: $files_created
      }'
    exit 0
  fi

  printf 'Created project: %s\n' "$project_name"
  printf '  Config: %s\n' "$config_display"
  printf '  Agents: %s\n' "$(join_by ", " "${AGENTS[@]}")"
  printf '  Coord:  %s\n' "$coord_path"
  if [[ $no_scripts == false ]]; then
    printf '  Run:    %s\n' "$bootstrap_display"
  else
    printf '  Run:    scripts not copied (--no-scripts)\n'
  fi
}

main "$@"
