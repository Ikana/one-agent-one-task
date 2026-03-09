#!/usr/bin/env bash

if [[ -t 2 ]]; then
  COLOR_RED=$'\033[31m'
  COLOR_YELLOW=$'\033[33m'
  COLOR_GREEN=$'\033[32m'
  COLOR_BLUE=$'\033[34m'
  COLOR_RESET=$'\033[0m'
else
  COLOR_RED=""
  COLOR_YELLOW=""
  COLOR_GREEN=""
  COLOR_BLUE=""
  COLOR_RESET=""
fi

info() {
  printf '%s[INFO]%s %s\n' "$COLOR_BLUE" "$COLOR_RESET" "$*" >&2
}

warn() {
  printf '%s[WARN]%s %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*" >&2
}

error() {
  printf '%s[ERROR]%s %s\n' "$COLOR_RED" "$COLOR_RESET" "$*" >&2
}

die() {
  local exit_code=$1
  shift
  error "$*"
  exit "$exit_code"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  local name=$1
  command_exists "$name" || die 1 "Missing required command: $name"
}

platform_name() {
  printf '%s/%s\n' "$(uname -s)" "$(uname -m)"
}

is_linux() {
  [[ $(uname -s) == "Linux" ]]
}

is_macos() {
  [[ $(uname -s) == "Darwin" ]]
}

is_arm64() {
  case "$(uname -m)" in
    arm64|aarch64) return 0 ;;
    *) return 1 ;;
  esac
}

trim() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

join_by() {
  local delimiter=$1
  shift
  local first=1
  local item
  for item in "$@"; do
    if [[ $first -eq 1 ]]; then
      printf '%s' "$item"
      first=0
    else
      printf '%s%s' "$delimiter" "$item"
    fi
  done
}

array_contains() {
  local needle=$1
  shift
  local item
  for item in "$@"; do
    if [[ $item == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

ensure_parent_dir() {
  local path=$1
  mkdir -p "$(dirname "$path")"
}

is_directory_nonempty() {
  local dir=$1
  [[ -d $dir ]] || return 1
  find "$dir" -mindepth 1 -maxdepth 1 | read -r _
}

confirm() {
  local prompt=$1
  local answer
  if [[ ! -t 0 ]]; then
    return 1
  fi
  printf '%s [y/N] ' "$prompt" >&2
  read -r answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

json_escape() {
  if command_exists jq; then
    jq -Rn --arg value "$1" '$value'
    return
  fi

  printf '"%s"' "$(printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e ':a;N;$!ba;s/\n/\\n/g')"
}

json_bool() {
  if [[ $1 == "true" ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

run_or_echo() {
  local dry_run=$1
  shift
  if [[ $dry_run == "true" ]]; then
    printf '[dry-run] %s\n' "$*" >&2
  else
    "$@"
  fi
}
