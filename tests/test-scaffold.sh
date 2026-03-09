#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCAFFOLD="$ROOT_DIR/scripts/scaffold.sh"
TMP_DIR=""

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f $1 ]] || fail "Expected file: $1"
}

assert_dir() {
  [[ -d $1 ]] || fail "Expected directory: $1"
}

assert_not_dir() {
  [[ ! -d $1 ]] || fail "Did not expect directory: $1"
}

assert_json5_parseable() {
  sed '/^[[:space:]]*\/\//d' "$1" | jq empty >/dev/null 2>&1 || fail "Expected parseable JSON5: $1"
}

main() {
  command -v jq >/dev/null 2>&1 || fail "jq is required"

  local project_dir
  local custom_dir
  local json_dir
  local force_dir
  local json_output

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  project_dir="$TMP_DIR/my-project"
  "$SCAFFOLD" my-project \
    --coord-path "$TMP_DIR/coord-host" \
    --output-dir "$project_dir" >/dev/null

  assert_dir "$project_dir/config"
  assert_dir "$project_dir/agents/communicator"
  assert_dir "$project_dir/coord/inbox/planner"
  assert_dir "$project_dir/coord/outbox/coder"
  assert_dir "$project_dir/scripts/lib"
  assert_file "$project_dir/config/openclaw.json5"
  assert_file "$project_dir/agents/communicator/AGENT.md"
  assert_file "$project_dir/scripts/bootstrap-pi.sh"
  assert_file "$project_dir/scripts/lib/common.sh"
  assert_file "$project_dir/docs/architecture.md"
  assert_json5_parseable "$project_dir/config/openclaw.json5"

  jq -er '.agents.list | map(.id) | index("communicator") != null' < <(sed '/^[[:space:]]*\/\//d' "$project_dir/config/openclaw.json5") >/dev/null || fail "Communicator missing from generated config"

  custom_dir="$TMP_DIR/custom"
  "$SCAFFOLD" custom \
    --agents "planner,coder" \
    --coord-path "$custom_dir/coord" \
    --output-dir "$custom_dir" >/dev/null

  assert_dir "$custom_dir/agents/communicator"
  assert_dir "$custom_dir/agents/planner"
  assert_dir "$custom_dir/agents/coder"
  assert_not_dir "$custom_dir/agents/researcher"

  jq -er '.agents.list | map(.id) == ["communicator","planner","coder"]' < <(sed '/^[[:space:]]*\/\//d' "$custom_dir/config/openclaw.json5") >/dev/null || fail "Custom agent set did not normalize as expected"

  force_dir="$TMP_DIR/force-target"
  mkdir -p "$force_dir"
  printf 'existing\n' >"$force_dir/existing.txt"
  "$SCAFFOLD" force-project \
    --coord-path "$force_dir/coord" \
    --output-dir "$force_dir" \
    --force >/dev/null

  assert_file "$force_dir/config/openclaw.json5"

  mkdir -p "$TMP_DIR/decline"
  printf 'existing\n' >"$TMP_DIR/decline/existing.txt"
  if "$SCAFFOLD" decline \
    --coord-path "$TMP_DIR/decline/coord" \
    --output-dir "$TMP_DIR/decline" >/dev/null 2>&1; then
    fail "Expected scaffold to refuse a non-empty directory without --force"
  else
    [[ $? -eq 2 ]] || fail "Expected exit code 2 for non-empty directory refusal"
  fi

  json_dir="$TMP_DIR/json-project"
  json_output=$("$SCAFFOLD" json-project \
    --coord-path "$json_dir/coord" \
    --output-dir "$json_dir" \
    --json)

  jq -e '
    .project == "json-project" and
    (.config | endswith("json-project/config/openclaw.json5")) and
    (.agents | index("communicator") != null) and
    (.files_created > 0)
  ' >/dev/null <<<"$json_output" || fail "JSON summary did not match the contract"

  printf 'test-scaffold.sh: PASS\n'
}

main "$@"
